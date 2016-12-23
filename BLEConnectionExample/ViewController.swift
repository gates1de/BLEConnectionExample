//
//  ViewController.swift
//  BLEConnectionExample
//
//  Created by Yu Kadowaki on 12/23/16.
//  Copyright © 2016 gates1de. All rights reserved.
//

import UIKit
import CoreBluetooth
import UserNotifications

internal class ViewController: UIViewController {

    // MARK: - IBOutlet

    @IBOutlet weak var statusLabel: UILabel!


    // MARK: - Internal Property

    var central: CBCentralManager?

    var peripheral: CBPeripheral?

    enum BLEModule: String {
        case Service    = "8080"
        case Read       = "8081"
        case Write      = "8082"

        var UUIDString: String {
            return "ada99a7f-888b-4e9f-\(self.rawValue)-07ddc240f3ce"
        }

        var cbUUID: CBUUID {
            return CBUUID(string: self.UUIDString)
        }
    }


    // MARK: - ViewController Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        central = CBCentralManager(delegate: self, queue: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let _ = peripheral {
            central?.scanForPeripherals(withServices: nil, options: nil)
        }
    }


    // MARK: - Internal Method

    /// 購入結果の通知を送信する
    func sendNotification(_ result: String) {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "購入結果"
        notificationContent.body = result
        notificationContent.sound = UNNotificationSound.default()

        let request = UNNotificationRequest(identifier: "DidReceiveResult", content: notificationContent, trigger: nil)

        let center = UNUserNotificationCenter.current()
        center.add(request) { error in
            if let error = error {
                print("notification error: \(error)")
            }
        }
    }
}


extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            statusLabel.text = "探索中..."
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // 見つかったperipheralのうち, serviceUUIDが今回利用したBLEモジュールのUUIDと一致するものがあれば接続する
        if let serviceUUIDList = advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? NSArray {
            guard serviceUUIDList.index(of: BLEModule.Service.UUIDString) == NSNotFound else {
                return
            }

            self.central?.stopScan()
            self.peripheral = peripheral

            guard let targetPeripheral = self.peripheral else {
                return
            }

            statusLabel.text = "接続中..."
            self.central?.connect(targetPeripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // 対象のperipheralが接続されたらサービスを探しに行く(BLEモジュールのserviceUUIDが合っていることを確認するため)
        self.peripheral?.delegate = self
        self.peripheral?.discoverServices([BLEModule.Service.cbUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        statusLabel.text = "接続に失敗しました..."
    }
}


extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // serviceが発見されたことを確認したら, read専用のcharacteristicを探しに行く
        guard let services = peripheral.services else {
            return
        }

        let targetServices = services.filter { $0.uuid == BLEModule.Service.cbUUID }

        if let service = targetServices.first {
            peripheral.discoverCharacteristics([BLEModule.Read.cbUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // read専用のcharacteristicが発見されたことを確認したら, データを受け取れる状態にしておく
        guard let characteristics = service.characteristics else {
            return
        }

        let targetCharacteristics = characteristics.filter { $0.uuid == BLEModule.Read.cbUUID }

        if let characteristic = targetCharacteristics.first {
            statusLabel.text = "接続済み"

            // ここでは何も返ってこない
            peripheral.readValue(for: characteristic)
            // これによりデータの受け取りを監視する
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // データの受け取り処理
        guard let readData = characteristic.value else {
            return
        }

        let result = IMBLEReadResult(data: readData)

        guard let resultText = result.text else {
            return
        }

        let beforeStatusText = self.statusLabel.text

        var resultBody = ""
        switch resultText {
        case "success":
            resultBody = "即購入が完了しました!"
            break
        case "failure":
            resultBody = "即購入に失敗しました..."
            break
        default:
            return
        }

        // 購入結果通知&表示
        sendNotification(resultBody)
        statusLabel.text = resultBody

        // 10秒後に状態表示ラベルの文字列をリセット
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: {
            self.statusLabel.text = beforeStatusText
        })
    }
}
