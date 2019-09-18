//
//  TransactionTests.swift
//
//  Copyright © 2018 Kishikawa Katsumi
//  Copyright © 2018 BitcoinKit developers
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import XCTest
@testable import BitcoinKit

class TransactionTests: XCTestCase {
    func testSignTransaction1() {
        // Transaction in testnet3
        // https://api.blockcypher.com/v1/btc/test3/txs/0189910c263c4d416d5c5c2cf70744f9f6bcd5feaf0b149b02e5d88afbe78992
        let prevTxID = "1524ca4eeb9066b4765effd472bc9e869240c4ecb5c1ee0edb40f8b666088231"
        let hash = Data(Data(hex: prevTxID)!.reversed())
        let index: UInt32 = 1
        let outpoint = TransactionOutPoint(hash: hash, index: index)

        let balance: UInt64 = 169012961
        let amount: UInt64  =  50000000
        let fee: UInt64     =  10000000
        let change: UInt64     =  balance - amount - fee
        let toAddress = try! AddressFactory.create("mv4rnyY3Su5gjcDNzbMLKBQkBicCtHUtFB") // https://testnet.coinfaucet.eu/en/

        let privateKey = try! PrivateKey(wif: "92pMamV6jNyEq9pDpY4f6nBy9KpV2cfJT4L5zDUYiGqyQHJfF1K")
        let changeAddress = privateKey.publicKey().toAddress()

        let lockScript = Script(address: changeAddress)!.data
        let output = TransactionOutput(value: 169012961, lockingScript: lockScript)
        let unspentTransaction = UnspentTransaction(output: output, outpoint: outpoint)
        let plan = TransactionPlan(unspentTransactions: [unspentTransaction], amount: amount, fee: fee, change: change)
        let transaction = TransactionBuilder.build(from: plan, toAddress: toAddress, changeAddress: changeAddress)
        let sighashHelper = BTCSignatureHashHelper(hashType: .ALL)
        let sighash = sighashHelper.createSignatureHash(of: transaction, for: unspentTransaction.output, inputIndex: 0)
        XCTAssertEqual(sighash.hex, "fd2f20da1c28b008abcce8a8ac7e1a7687fc944e001a24fc3aacb6a7570a3d0f")
        let signature = privateKey.sign(sighash)
        XCTAssertEqual(signature.hex, "3044022074ddd327544e982d8dd53514406a77a96de47f40c186e58cafd650dd71ea522702204f67c558cc8e771581c5dda630d0dfff60d15e43bf13186669392936ec539d03")
        let signer = TransactionSigner(unspentTransactions: plan.unspentTransactions, transaction: transaction, sighashHelper: BTCSignatureHashHelper(hashType: .ALL))
        let signedTransaction = try! signer.sign(with: [privateKey])
        XCTAssertEqual(signedTransaction.serialized().hex, "010000000131820866b6f840db0eeec1b5ecc44092869ebc72d4ff5e76b46690eb4eca2415010000008a473044022074ddd327544e982d8dd53514406a77a96de47f40c186e58cafd650dd71ea522702204f67c558cc8e771581c5dda630d0dfff60d15e43bf13186669392936ec539d030141047e000cc16c9a4d38cb1572b9dc34c1452626aa170b46150d0e806be1b42517f0832c8a58f543128083ffb8632bae94dd5f3e1e89fad0a17f64ed8bbbb90b5753ffffffff0280f0fa02000000001976a9149f9a7abd600c0caa03983a77c8c3df8e062cb2fa88ace1677f06000000001976a9142a539adfd7aefcc02e0196b4ccf76aea88a1f47088ac00000000")
        XCTAssertEqual(signedTransaction.txID, "0189910c263c4d416d5c5c2cf70744f9f6bcd5feaf0b149b02e5d88afbe78992")
    }

    func testSignTransaction2() {
        // Transaction on Bitcoin Cash Mainnet
        // TxID : 96ee20002b34e468f9d3c5ee54f6a8ddaa61c118889c4f35395c2cd93ba5bbb4
        // https://explorer.bitcoin.com/bch/tx/96ee20002b34e468f9d3c5ee54f6a8ddaa61c118889c4f35395c2cd93ba5bbb4
        let toAddress: Address = try! AddressFactory.create("1Bp9U1ogV3A14FMvKbRJms7ctyso4Z4Tcx")
        let changeAddress: Address = try! AddressFactory.create("1FQc5LdgGHMHEN9nwkjmz6tWkxhPpxBvBU")

        let unspentOutput = TransactionOutput(value: 5151, lockingScript: Data(hex: "76a914aff1e0789e5fe316b729577665aa0a04d5b0f8c788ac")!)
        let unspentOutpoint = TransactionOutPoint(hash: Data(hex: "e28c2b955293159898e34c6840d99bf4d390e2ee1c6f606939f18ee1e2000d05")!, index: 2)
        let unspentTransaction = UnspentTransaction(output: unspentOutput, outpoint: unspentOutpoint)
        let utxoKey = try! PrivateKey(wif: "L1WFAgk5LxC5NLfuTeADvJ5nm3ooV3cKei5Yi9LJ8ENDfGMBZjdW")

        let feePerByte: UInt64 = 1
        let planner = TransactionPlanner(feePerByte: feePerByte)
        let plan = planner.plan(unspentTransactions: [unspentTransaction], target: 600)
        let transaction = TransactionBuilder.build(from: plan, toAddress: toAddress, changeAddress: changeAddress)
        
        let signer = TransactionSigner(unspentTransactions: plan.unspentTransactions, transaction: transaction, sighashHelper: BCHSignatureHashHelper(hashType: .ALL))
        let signedTransaction = try! signer.sign(with: [utxoKey])

        XCTAssertEqual(signedTransaction.txID, "96ee20002b34e468f9d3c5ee54f6a8ddaa61c118889c4f35395c2cd93ba5bbb4")
        XCTAssertEqual(signedTransaction.serialized().hex, "0100000001e28c2b955293159898e34c6840d99bf4d390e2ee1c6f606939f18ee1e2000d05020000006b483045022100b70d158b43cbcded60e6977e93f9a84966bc0cec6f2dfd1463d1223a90563f0d02207548d081069de570a494d0967ba388ff02641d91cadb060587ead95a98d4e3534121038eab72ec78e639d02758e7860cdec018b49498c307791f785aa3019622f4ea5bffffffff0258020000000000001976a914769bdff96a02f9135a1d19b749db6a78fe07dc9088ace5100000000000001976a9149e089b6889e032d46e3b915a3392edfd616fb1c488ac00000000")
    }

    func testIsCoinbase() {
        let data = Data(hex: "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff025151ffffffff010000000000000000015100000000")!
        let tx = Transaction.deserialize(data)
        XCTAssert(tx.isCoinbase())
    }
}
