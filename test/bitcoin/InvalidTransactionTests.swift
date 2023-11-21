import XCTest
@testable import Bitcoin

final class InvalidTransactionTests: XCTestCase {

    override class func setUp() {
        eccStart()
    }

    override class func tearDown() {
        eccStop()
    }

    func testInvalidTransactions() throws {
        for vector in testVectors {
            guard
                let expectedTransactionData = Data(hex: vector.serializedTransaction),
                let tx = Transaction(expectedTransactionData)
            else {
                XCTFail(); continue
            }
            let previousOutputs = vector.previousOutputs.map { previousOutput in
                Output(value: previousOutput.amount, script: ParsedScript(previousOutput.scriptOperations))
            }
            var includeFlags = Set(vector.verifyFlags.split(separator: ","))
            includeFlags.remove("NONE")
            if includeFlags.contains("BADTX") {
                XCTAssertThrowsError(try tx.check())
                continue
            } else {
                XCTAssertNoThrow(try tx.check())
            }
            includeFlags.remove("BADTX")
            let config = ScriptConfigurarion(
                strictDER: includeFlags.contains("DERSIG"),
                pushOnly:  includeFlags.contains("SIGPUSHONLY"),
                lowS: includeFlags.contains("LOW_S"),
                cleanStack: includeFlags.contains("CLEANSTACK"),
                nullDummy: includeFlags.contains("NULLDUMMY"),
                strictEncoding: includeFlags.contains("STRICTENC"),
                payToScriptHash: includeFlags.contains("P2SH"),
                checkLockTimeVerify: includeFlags.contains("CHECKLOCKTIMEVERIFY"),
                lockTimeSequence: false,
                checkSequenceVerify: includeFlags.contains("CHECKSEQUENCEVERIFY"),
                constantScriptCode: includeFlags.contains("CONST_SCRIPTCODE"),
                witness: includeFlags.contains("WITNESS"),
                witnessCompressedPublicKey: false,
                minimalIf: false,
                nullFail: includeFlags.contains("NULLFAIL"),
                discourageUpgradableWitnessProgram: includeFlags.contains("DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM"),
                taproot: false,
                discourageUpgradableTaprootVersion: false
            )
            let result = tx.verify(previousOutputs: previousOutputs, configuration: config)
            XCTAssertFalse(result)

            if !includeFlags.isEmpty {
                let configSuccess = ScriptConfigurarion.init(strictDER: false, pushOnly: false, lowS: false, cleanStack: false, nullDummy: false, strictEncoding: false, payToScriptHash: false, checkLockTimeVerify: false, checkSequenceVerify: false, constantScriptCode: false, witness: false, witnessCompressedPublicKey: false, minimalIf: false, nullFail: false, discourageUpgradableWitnessProgram: false, taproot: false, discourageUpgradableTaprootVersion: false)
                let resultSuccess = tx.verify(previousOutputs: previousOutputs, configuration: configSuccess)
                XCTAssert(resultSuccess)
            }
        }
    }
}

fileprivate struct TestVector {

    struct PreviousOutput {
        let transactionIdentifier: String
        let outputIndex: Int
        let amount: Int
        let scriptOperations: [ScriptOperation]
    }

    let previousOutputs: [PreviousOutput]
    let serializedTransaction: String
    let verifyFlags: String
}

fileprivate let testVectors: [TestVector] = [

    // MARK: - Invalid transactions
    // The following are deserialized transactions which are invalid.

    // 0e1b5688cf179cd9f7cbda1fac0090f6e684bbf8cd946660120197c3f3681809 but with extra junk appended to the end of the scriptPubKey
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "6ca7ec7b1847f6bdbd737176050e6a08d66ccd55bb94ad24f4018024107a5827",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "043b640e983c9690a14c039a2037ecc3467b27a0dcd58f19d76c7bc118d09fec45adc5370a1c5bf8067ca9f5557a4cf885fdb0fe0dcc9c3a7137226106fbc779a5")!),
                    .checkSig,
                    .verify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "010000000127587a10248001f424ad94bb55cd6cd6086a0e05767173bdbdf647187beca76c000000004948304502201b822ad10d6adc1a341ae8835be3f70a25201bbff31f59cbb9c5353a5f0eca18022100ea7b2f7074e9aa9cf70aa8d0ffee13e6b45dddabf1ab961bda378bcdb778fa4701ffffffff0100f2052a010000001976a914fc50c5907d86fed474ba5ce8b12a66e0a4c139d888ac00000000",
        verifyFlags: "NONE"
    ),

    // This is the nearly-standard transaction with CHECKSIGVERIFY 1 instead of CHECKSIG from tx_valid.json but with the signature duplicated in the scriptPubKey with a non-standard pushdata prefix
    // See FindAndDelete, which will only remove if it uses the same pushdata prefix as is standard
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "5b6462475454710f3c22f5fdf0b40704c92f25c3")!),
                    .equalVerify,
                    .checkSigVerify,
                    .constant(1),
                    .pushData1(.init(hex: "3044022067288ea50aa799543a536ff9306f8e1cba05b9c6b10951175b924f96732555ed022026d7b5265f38d21541519e4a1e55044d5b9e17e15cdbaf29ae3792e99e883e7a01")!),
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006a473044022067288ea50aa799543a536ff9306f8e1cba05b9c6b10951175b924f96732555ed022026d7b5265f38d21541519e4a1e55044d5b9e17e15cdbaf29ae3792e99e883e7a012103ba8c8b86dea131c22ab967e6dd99bdae8eff7a1f75a2c35f1f944109e3fe5e22ffffffff010000000000000000015100000000",
        verifyFlags: "NONE"
    ),

    // Same as above, but with the sig in the scriptSig also pushed with the same non-standard OP_PUSHDATA
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "5b6462475454710f3c22f5fdf0b40704c92f25c3")!),
                    .equalVerify,
                    .checkSigVerify,
                    .constant(1),
                    .pushData1(.init(hex: "3044022067288ea50aa799543a536ff9306f8e1cba05b9c6b10951175b924f96732555ed022026d7b5265f38d21541519e4a1e55044d5b9e17e15cdbaf29ae3792e99e883e7a01")!),
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006b4c473044022067288ea50aa799543a536ff9306f8e1cba05b9c6b10951175b924f96732555ed022026d7b5265f38d21541519e4a1e55044d5b9e17e15cdbaf29ae3792e99e883e7a012103ba8c8b86dea131c22ab967e6dd99bdae8eff7a1f75a2c35f1f944109e3fe5e22ffffffff010000000000000000015100000000",
        verifyFlags: "NONE"
    ),

    // This is the nearly-standard transaction with CHECKSIGVERIFY 1 instead of CHECKSIG from tx_valid.json but with the signature duplicated in the scriptPubKey with a different hashtype suffix
    // See FindAndDelete, which will only remove if the signature, including the hash type, matches
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "5b6462475454710f3c22f5fdf0b40704c92f25c3")!),
                    .equalVerify,
                    .checkSigVerify,
                    .constant(1),
                    .pushBytes(.init(hex: "3044022067288ea50aa799543a536ff9306f8e1cba05b9c6b10951175b924f96732555ed022026d7b5265f38d21541519e4a1e55044d5b9e17e15cdbaf29ae3792e99e883e7a81")!),
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006a473044022067288ea50aa799543a536ff9306f8e1cba05b9c6b10951175b924f96732555ed022026d7b5265f38d21541519e4a1e55044d5b9e17e15cdbaf29ae3792e99e883e7a012103ba8c8b86dea131c22ab967e6dd99bdae8eff7a1f75a2c35f1f944109e3fe5e22ffffffff010000000000000000015100000000",
        verifyFlags: "NONE"
    ),

    // An invalid P2SH Transaction
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "7a052c840ba73af26755de42cf01cc9e0a49fef0")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000009085768617420697320ffffffff010000000000000000015100000000",
        verifyFlags: "P2SH"
    ),

    // MARK: - Tests for CheckTransaction()

    // No outputs
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "05ab9e14d983742513f0f451e105ffb4198d1dd4")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006d483045022100f16703104aab4e4088317c862daec83440242411b039d14280e03dd33b487ab802201318a7be236672c5c56083eb7a5a195bc57a40af7923ff8545016cd3b571e2a601232103c40e5d339df3f30bf753e7e04450ae4ef76c9e45587d1d993bdc4cd06f0651c7acffffffff0000000000",
        verifyFlags: "BADTX"
    ),

    // Negative output
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "ae609aca8061d77c5e111f6bb62501a6bbe2bfdb")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006d4830450220063222cbb128731fc09de0d7323746539166544d6c1df84d867ccea84bcc8903022100bf568e8552844de664cd41648a031554327aa8844af34b4f27397c65b92c04de0123210243ec37dee0e2e053a9c976f43147e79bc7d9dc606ea51010af1ac80db6b069e1acffffffff01ffffffffffffffff015100000000",
        verifyFlags: "BADTX"
    ),

    // MAX_MONEY + 1 output
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "32afac281462b822adbec5094b8d4d337dd5bd6a")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006e493046022100e1eadba00d9296c743cb6ecc703fd9ddc9b3cd12906176a226ae4c18d6b00796022100a71aef7d2874deff681ba6080f1b278bac7bb99c61b08a85f4311970ffe7f63f012321030c0588dc44d92bdcbf8e72093466766fdc265ead8db64517b0c542275b70fffbacffffffff010140075af0750700015100000000",
        verifyFlags: "BADTX"
    ),

    // MAX_MONEY output + 1 output
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "b558cbf4930954aa6a344363a15668d7477ae716")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006d483045022027deccc14aa6668e78a8c9da3484fbcd4f9dcc9bb7d1b85146314b21b9ae4d86022100d0b43dece8cfb07348de0ca8bc5b86276fa88f7f2138381128b7c36ab2e42264012321029bb13463ddd5d2cc05da6e84e37536cb9525703cfd8f43afdb414988987a92f6acffffffff020040075af075070001510001000000000000015100000000",
        verifyFlags: "BADTX"
    ),

    // Duplicate inputs
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "236d0639db62b0773fd8ac34dc85ae19e9aba80a")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000020001000000000000000000000000000000000000000000000000000000000000000000006c47304402204bb1197053d0d7799bf1b30cd503c44b58d6240cccbdc85b6fe76d087980208f02204beeed78200178ffc6c74237bb74b3f276bbb4098b5605d814304fe128bf1431012321039e8815e15952a7c3fada1905f8cf55419837133bd7756c0ef14fc8dfe50c0deaacffffffff0001000000000000000000000000000000000000000000000000000000000000000000006c47304402202306489afef52a6f62e90bf750bbcdf40c06f5c6b138286e6b6b86176bb9341802200dba98486ea68380f47ebb19a7df173b99e6bc9c681d6ccf3bde31465d1f16b3012321039e8815e15952a7c3fada1905f8cf55419837133bd7756c0ef14fc8dfe50c0deaacffffffff010000000000000000015100000000",
        verifyFlags: "BADTX"
    ),

    // Coinbase of size 1
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000000",
                outputIndex: -1,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff0151ffffffff010000000000000000015100000000",
        verifyFlags: "BADTX"
    ),

    // Coinbase of size 101
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000000",
                outputIndex: -1,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff655151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151ffffffff010000000000000000015100000000",
        verifyFlags: "BADTX"
    ),

    // Null txin, but without being a coinbase (because there are two inputs)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000000",
                outputIndex: -1,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "01000000020000000000000000000000000000000000000000000000000000000000000000ffffffff00ffffffff00010000000000000000000000000000000000000000000000000000000000000000000000ffffffff010000000000000000015100000000",
        verifyFlags: "BADTX"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000000",
                outputIndex: -1,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "010000000200010000000000000000000000000000000000000000000000000000000000000000000000ffffffff0000000000000000000000000000000000000000000000000000000000000000ffffffff00ffffffff010000000000000000015100000000",
        verifyFlags: "BADTX"
    ),

    // MARK: - Other invalid transactions

    // Same as the transactions in valid with one input SIGHASH_ALL and one SIGHASH_ANYONECANPAY, but we set the _ANYONECANPAY sequence number, invalidating the SIGHASH_ALL signature
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "035e7f0d4d0841bcd56c39337ed086b1a633ee770c1ffdd94ac552a95ac2ce0efc")!),
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000200",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "035e7f0d4d0841bcd56c39337ed086b1a633ee770c1ffdd94ac552a95ac2ce0efc")!),
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000020001000000000000000000000000000000000000000000000000000000000000000000004948304502203a0f5f0e1f2bdbcd04db3061d18f3af70e07f4f467cbc1b8116f267025f5360b022100c792b6e215afc5afc721a351ec413e714305cb749aae3d7fee76621313418df10101000000000200000000000000000000000000000000000000000000000000000000000000000000484730440220201dc2d030e380e8f9cfb41b442d930fa5a685bb2c8db5906671f865507d0670022018d9e7a8d4c8d86a73c2a724ee38ef983ec249827e0e464841735955c707ece98101000000010100000000000000015100000000",
        verifyFlags: "NONE"
    ),

    // CHECKMULTISIG with incorrect signature order
    // Note the input is just required to make the tester happy
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "b3da01dd4aae683c7aee4d5d8b52a540a508e1115f77cd7fa9a291243f501223",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "b1ce99298d5f07364b57b1e5c9cc00be0b04a954")!),
                    .equal
                ]
            ),
        ],
        serializedTransaction: "01000000012312503f2491a2a97fcd775f11e108a540a5528b5d4dee7a3c68ae4add01dab300000000fdfe000048304502207aacee820e08b0b174e248abd8d7a34ed63b5da3abedb99934df9fddd65c05c4022100dfe87896ab5ee3df476c2655f9fbe5bd089dccbef3e4ea05b5d121169fe7f5f401483045022100f6649b0eddfdfd4ad55426663385090d51ee86c3481bdc6b0c18ea6c0ece2c0b0220561c315b07cffa6f7dd9df96dbae9200c2dee09bf93cc35ca05e6cdf613340aa014c695221031d11db38972b712a9fe1fc023577c7ae3ddb4a3004187d41c45121eecfdbb5b7210207ec36911b6ad2382860d32989c7b8728e9489d7bbc94a6b5509ef0029be128821024ea9fac06f666a4adc3fc1357b7bec1fd0bdece2b9d08579226a8ebde53058e453aeffffffff0180380100000000001976a914c9b99cddf847d10685a4fabaa0baf505f7c3dfab88ac00000000",
        verifyFlags: "P2SH"
    ),

    // The following is a tweaked form of 23b397edccd3740a74adb603c9756370fafcde9bcc4483eb271ecad09a94dd63
    // It is an OP_CHECKMULTISIG with the dummy value missing
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0x0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            ),
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba260000000004847304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2b01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "NONE"
    ),

    // MARK: - CHECKMULTISIG SCRIPT_VERIFY_NULLDUMMY tests:

    // The following is a tweaked form of 23b397edccd3740a74adb603c9756370fafcde9bcc4483eb271ecad09a94dd63
    // It is an OP_CHECKMULTISIG with the dummy value set to something other than an empty string
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            ),
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba260000000004a010047304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2b01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "NULLDUMMY"
    ),

    // As above, but using an OP_1
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            ),
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba26000000000495147304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2b01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "NULLDUMMY"
    ),

    // As above, but using an OP_1NEGATE
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            ),
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba26000000000494f47304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2b01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "NULLDUMMY"
    ),

    // As above, but with the dummy byte missing
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            ),
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba260000000004847304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2b01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "NONE"
    ),

    // Empty stack when we try to run CHECKSIG
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "ad503f72c18df5801ee64d76090afe4c607fb2b822e9b7b63c5826c50e22fc3b",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "027c3a97665bf283a102a587a62a30a0c102d4d3b141015e2cae6f64e2543113e5")!),
                    .checkSig,
                    .not
                ]
            ),
        ],
        serializedTransaction: "01000000013bfc220ec526583cb6b7e922b8b27f604cfe0a09764de61e80f58dc1723f50ad0000000000ffffffff0101000000000000002321027c3a97665bf283a102a587a62a30a0c102d4d3b141015e2cae6f64e2543113e5ac00000000",
        verifyFlags: "NONE"
    ),

    // MARK: - Inverted versions of tx_valid CODESEPARATOR IF block tests

    // CODESEPARATOR in an unexecuted IF block does not change what is hashed
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "a955032f4d6b0c9bfe8cad8f00a8933790b9c1dc28c82e0f48e75b35da0e4944",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .if,
                    .codeSeparator,
                    .endIf,
                    .pushBytes(.init(hex: "0378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c71")!),
                    .checkSigVerify,
                    .codeSeparator,
                    .constant(1)
                ]
            ),
        ],
        serializedTransaction: "010000000144490eda355be7480f2ec828dcc1b9903793a8008fad8cfe9b0c6b4d2f0355a9000000004a48304502207a6974a77c591fa13dff60cabbb85a0de9e025c09c65a4b2285e47ce8e22f761022100f0efaac9ff8ac36b10721e0aae1fb975c90500b50c56e8a0cc52b0403f0425dd0151ffffffff010000000000000000016a00000000",
        verifyFlags: "NONE"
    ),

    // As above, with the IF block executed
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "a955032f4d6b0c9bfe8cad8f00a8933790b9c1dc28c82e0f48e75b35da0e4944",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .if,
                    .codeSeparator,
                    .endIf,
                    .pushBytes(.init(hex: "0378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c71")!),
                    .checkSigVerify,
                    .codeSeparator,
                    .constant(1)
                ]
            ),
        ],
        serializedTransaction: "010000000144490eda355be7480f2ec828dcc1b9903793a8008fad8cfe9b0c6b4d2f0355a9000000004a483045022100fa4a74ba9fd59c59f46c3960cf90cbe0d2b743c471d24a3d5d6db6002af5eebb02204d70ec490fd0f7055a7c45f86514336e3a7f03503dacecabb247fc23f15c83510100ffffffff010000000000000000016a00000000",
        verifyFlags: "NONE"
    ),

    // MARK: - CHECKLOCKTIMEVERIFY tests

    // By-height locks, with argument just beyond tx nLockTime
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "1dcd64ff")!.reversed())), // 499_999_999
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "0100000001000100000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000fe64cd1d",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    // By-time locks, with argument just beyond tx nLockTime (but within numerical boundaries)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "1dcd6501")!.reversed())), // 500_000_001
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000065cd1d",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "00ffffffff")!.reversed())), // 4_294_967_295
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "0100000001000100000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000feffffff",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    // Argument missing
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .checkLockTimeVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000001b1010000000100000000000000000000000000",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    // Argument negative with by-blockheight nLockTime=0
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .oneNegate,
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    // Argument negative with by-blocktime nLockTime=500,000,000
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .oneNegate,
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000065cd1d",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000004005194b1010000000100000000000000000002000000",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    // Input locked
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .zero,
                    .checkLockTimeVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffffff0100000000000000000000000000",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .zero
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000000251b1ffffffff0100000000000000000002000000",
        verifyFlags: "NONE"
    ),

    // Another input being unlocked isn't sufficient; the CHECKLOCKTIMEVERIFY-using input must be unlocked
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .zero,
                    .checkLockTimeVerify,
                    .constant(1)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000200",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "010000000200010000000000000000000000000000000000000000000000000000000000000000000000ffffffff00020000000000000000000000000000000000000000000000000000000000000100000000000000000100000000000000000000000000",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),


    // Argument/tx height/time mismatch, both versions
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .zero,
                    .checkLockTimeVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000065cd1d",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .zero
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000000251b100000000010000000000000000000065cd1d",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "1dcd64ff")!.reversed())), // 499_999_999
                    .checkLockTimeVerify,
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000065cd1d",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "1dcd6500")!.reversed())), // 500_000_000
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "1dcd6500")!.reversed())), // 500_000_000
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "0100000001000100000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000ff64cd1d",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    // Argument 2^32 with nLockTime=2^32-1
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "1000000000")!.reversed())),
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "0100000001000100000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000ffffffff",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    // Same, but with nLockTime=2^31-1
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "0080000000")!.reversed())), // 2_147_483_648
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "0100000001000100000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000ffffff7f",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    // 6 byte non-minimally-encoded arguments are invalid even if their contents are valid
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "000000000000")!),
                    .checkLockTimeVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    // Failure due to failing CHECKLOCKTIMEVERIFY in scriptSig
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000000251b1000000000100000000000000000000000000",
        verifyFlags: "CHECKLOCKTIMEVERIFY"
    ),

    // Failure due to failing CHECKLOCKTIMEVERIFY in redeemScript
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "c5b93064159b3b2d6ab506a41b1f50463771b988")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "0100000001000100000000000000000000000000000000000000000000000000000000000000000000030251b1000000000100000000000000000000000000",
        verifyFlags: "P2SH,CHECKLOCKTIMEVERIFY"
    ),

    // A transaction with a non-standard DER signature.
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "b1dbc81696c8a9c0fccd0693ab66d7c368dbc38c0def4e800685560ddd1b2132",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "4b3bd7eba3bc0284fd3007be7f3be275e94f5826")!),
                    .equalVerify,
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "010000000132211bdd0d568506804eef0d8cc3db68c3d766ab9306cdfcc0a9c89616c8dbb1000000006c493045022100c7bb0faea0522e74ff220c20c022d2cb6033f8d167fb89e75a50e237a35fd6d202203064713491b1f8ad5f79e623d0219ad32510bfaa1009ab30cbee77b59317d6e30001210237af13eb2d84e4545af287b919c2282019c9691cc509e78e196a9d8274ed1be0ffffffff0100000000000000001976a914f1b3ed2eda9a2ebe5a9374f692877cdf87c0f95b88ac00000000",
        verifyFlags: "DERSIG"
    ),

    // MARK: - CHECKSEQUENCEVERIFY tests

    // By-height locks, with argument just beyond txin.nSequence
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .checkSequenceVerify,
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "40ffff")!.reversed())), // 4_259_839
                    .checkSequenceVerify,
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000feff40000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    // By-time locks, with argument just beyond txin.nSequence (but within numerical boundaries)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "400001")!.reversed())), // 4_194_305
                    .checkSequenceVerify,
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000040000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "40ffff")!.reversed())), // 4_259_839
                    .checkSequenceVerify,
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000feff40000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    // Argument missing
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .checkSequenceVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    // Argument negative with by-blockheight txin.nSequence=0
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .oneNegate,
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    // Argument negative with by-blocktime txin.nSequence=CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .oneNegate,
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000040000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    // Argument/tx height/time mismatch, both versions
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .zero,
                    .checkSequenceVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000040000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "00ffff")!.reversed())), // 65_535
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000040000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "400000")!.reversed())), // 4_194_304
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "40ffff")!.reversed())), // 4_259_839
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    // 6 byte non-minimally-encoded arguments are invalid even if their contents are valid
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "000000000000")!),
                    .checkSequenceVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffff00000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    // Failure due to failing CHECKSEQUENCEVERIFY in scriptSig
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "02000000010001000000000000000000000000000000000000000000000000000000000000000000000251b2000000000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    // Failure due to failing CHECKSEQUENCEVERIFY in redeemScript
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "7c17aff532f22beb54069942f9bf567a66133eaf")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "0200000001000100000000000000000000000000000000000000000000000000000000000000000000030251b2000000000100000000000000000000000000",
        verifyFlags: "P2SH,CHECKSEQUENCEVERIFY"
    ),

    // Failure due to insufficient tx.nVersion (<2)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .zero,
                    .checkSequenceVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "400000")!.reversed())), // 4_194_304
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000000000040000100000000000000000000000000",
        verifyFlags: "CHECKSEQUENCEVERIFY"
    ),

    // MARK: - Segwit tests

    // Unknown witness program version (with DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 1000,
                scriptOperations: [
                    .constant(1)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 1,
                amount: 2000,
                scriptOperations: [
                    .constant(16),
                    .pushBytes(.init(hex: "4c9c3dfac4207d5d8cb89df5722cb3d712385e3f")!)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 2,
                amount: 3000,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "0100000000010300010000000000000000000000000000000000000000000000000000000000000000000000ffffffff00010000000000000000000000000000000000000000000000000000000000000100000000ffffffff00010000000000000000000000000000000000000000000000000000000000000200000000ffffffff03e8030000000000000151d0070000000000000151b80b00000000000001510002483045022100a3cec69b52cba2d2de623ffffffffff1606184ea55476c0f8189fda231bc9cbb022003181ad597f7c380a7d1c740286b1d022b8b04ded028b833282e055e03b8efef812103596d3451025c19dbbdeb932d6bf8bfb4ad499b95b6f88db8899efac102e5fc710000000000",
        verifyFlags: "P2SH,WITNESS,DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM"
    ),

    // Unknown length for witness program v0
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 1000,
                scriptOperations: [
                    .constant(1)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 1,
                amount: 2000,
                scriptOperations: [
                    .zero,
                    .pushBytes(.init(hex: "4c9c3dfac4207d5d8cb89df5722cb3d712385e3fff")!)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 2,
                amount: 3000,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "0100000000010300010000000000000000000000000000000000000000000000000000000000000000000000ffffffff00010000000000000000000000000000000000000000000000000000000000000100000000ffffffff00010000000000000000000000000000000000000000000000000000000000000200000000ffffffff04b60300000000000001519e070000000000000151860b0000000000000100960000000000000001510002473044022022fceb54f62f8feea77faac7083c3b56c4676a78f93745adc8a35800bc36adfa022026927df9abcf0a8777829bcfcce3ff0a385fa54c3f9df577405e3ef24ee56479022103596d3451025c19dbbdeb932d6bf8bfb4ad499b95b6f88db8899efac102e5fc710000000000",
        verifyFlags: "P2SH,WITNESS"
    ),

    // Witness with SigHash Single|AnyoneCanPay (same index output value changed)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 1000,
                scriptOperations: [
                    .constant(1)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 1,
                amount: 2000,
                scriptOperations: [
                    .zero,
                    .pushBytes(.init(hex: "4c9c3dfac4207d5d8cb89df5722cb3d712385e3f")!)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 2,
                amount: 3000,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "0100000000010300010000000000000000000000000000000000000000000000000000000000000000000000ffffffff00010000000000000000000000000000000000000000000000000000000000000100000000ffffffff00010000000000000000000000000000000000000000000000000000000000000200000000ffffffff03e80300000000000001516c070000000000000151b80b0000000000000151000248304502210092f4777a0f17bf5aeb8ae768dec5f2c14feabf9d1fe2c89c78dfed0f13fdb86902206da90a86042e252bcd1e80a168c719e4a1ddcc3cebea24b9812c5453c79107e9832103596d3451025c19dbbdeb932d6bf8bfb4ad499b95b6f88db8899efac102e5fc710000000000",
        verifyFlags: "P2SH,WITNESS"
    ),

    // Witness with SigHash None|AnyoneCanPay (input sequence changed)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 1000,
                scriptOperations: [
                    .constant(1)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 1,
                amount: 2000,
                scriptOperations: [
                    .zero,
                    .pushBytes(.init(hex: "4c9c3dfac4207d5d8cb89df5722cb3d712385e3f")!)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 2,
                amount: 3000,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "0100000000010300010000000000000000000000000000000000000000000000000000000000000000000000ffffffff000100000000000000000000000000000000000000000000000000000000000001000000000100000000010000000000000000000000000000000000000000000000000000000000000200000000ffffffff03e8030000000000000151d0070000000000000151b80b0000000000000151000248304502210091b32274295c2a3fa02f5bce92fb2789e3fc6ea947fbe1a76e52ea3f4ef2381a022079ad72aefa3837a2e0c033a8652a59731da05fa4a813f4fc48e87c075037256b822103596d3451025c19dbbdeb932d6bf8bfb4ad499b95b6f88db8899efac102e5fc710000000000",
        verifyFlags: "P2SH,WITNESS"
    ),

    // Witness with SigHash All|AnyoneCanPay (third output value changed)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 1000,
                scriptOperations: [
                    .constant(1)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 1,
                amount: 2000,
                scriptOperations: [
                    .zero,
                    .pushBytes(.init(hex: "4c9c3dfac4207d5d8cb89df5722cb3d712385e3f")!)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 2,
                amount: 3000,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "0100000000010300010000000000000000000000000000000000000000000000000000000000000000000000ffffffff00010000000000000000000000000000000000000000000000000000000000000100000000ffffffff00010000000000000000000000000000000000000000000000000000000000000200000000ffffffff03e8030000000000000151d0070000000000000151540b00000000000001510002483045022100a3cec69b52cba2d2de623eeef89e0ba1606184ea55476c0f8189fda231bc9cbb022003181ad597f7c380a7d1c740286b1d022b8b04ded028b833282e055e03b8efef812103596d3451025c19dbbdeb932d6bf8bfb4ad499b95b6f88db8899efac102e5fc710000000000",
        verifyFlags: "P2SH,WITNESS"
    ),

    // Witness with a push of 521 bytes
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 1000,
                scriptOperations: [
                    .zero,
                    .pushBytes(.init(hex: "0x33198a9bfef674ebddb9ffaa52928017b8472791e54c609cb95f278ac6b1e349")!)
                ]
            )
        ],
        serializedTransaction: "0100000000010100010000000000000000000000000000000000000000000000000000000000000000000000ffffffff010000000000000000015102fd0902000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002755100000000",
        verifyFlags: "P2SH,WITNESS"
    ),

    // Witness with unknown version which push false on the stack should be invalid (even without DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 2000,
                scriptOperations: [
                    .constant(16),
                    .pushBytes(.init(hex: "0000")!)
                ]
            )
        ],
        serializedTransaction: "0100000000010100010000000000000000000000000000000000000000000000000000000000000000000000ffffffff010000000000000000015101010100000000",
        verifyFlags: "NONE"
    ),

    // Witness program should leave clean stack
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 2000,
                scriptOperations: [
                    .zero,
                    .pushBytes(.init(hex: "2f04a3aa051f1f60d695f6c44c0c3d383973dfd446ace8962664a76bb10e31a8")!)
                ]
            )
        ],
        serializedTransaction: "0100000000010100010000000000000000000000000000000000000000000000000000000000000000000000ffffffff01000000000000000001510102515100000000",
        verifyFlags: "P2SH,WITNESS"
    ),

    // Witness v0 with a push of 2 bytes
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 2000,
                scriptOperations: [
                    .zero,
                    .pushBytes(.init(hex: "0001")!)
                ]
            )
        ],
        serializedTransaction: "0100000000010100010000000000000000000000000000000000000000000000000000000000000000000000ffffffff010000000000000000015101040002000100000000",
        verifyFlags: "P2SH,WITNESS"
    ),

    // Unknown witness version with non empty scriptSig
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 2000,
                scriptOperations: [
                    .constant(16),
                    .pushBytes(.init(hex: "0001")!)
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000000151ffffffff010000000000000000015100000000",
        verifyFlags: "P2SH,WITNESS"
    ),

    // Non witness Single|AnyoneCanPay hash input's position (permutation)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 1000,
                scriptOperations: [
                    .pushBytes(.init(hex: "03596d3451025c19dbbdeb932d6bf8bfb4ad499b95b6f88db8899efac102e5fc71")!),
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 1,
                amount: 1001,
                scriptOperations: [
                    .pushBytes(.init(hex: "03596d3451025c19dbbdeb932d6bf8bfb4ad499b95b6f88db8899efac102e5fc71")!),
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "010000000200010000000000000000000000000000000000000000000000000000000000000100000049483045022100acb96cfdbda6dc94b489fd06f2d720983b5f350e31ba906cdbd800773e80b21c02200d74ea5bdf114212b4bbe9ed82c36d2e369e302dff57cb60d01c428f0bd3daab83ffffffff0001000000000000000000000000000000000000000000000000000000000000000000004847304402202a0b4b1294d70540235ae033d78e64b4897ec859c7b6f1b2b1d8a02e1d46006702201445e756d2254b0f1dfda9ab8e1e1bc26df9668077403204f32d16a49a36eb6983ffffffff02e9030000000000000151e803000000000000015100000000",
        verifyFlags: "NONE"
    ),

    // P2WSH with a redeem representing a witness scriptPubKey should fail due to too many stack items
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 1000,
                scriptOperations: [
                    .zero,
                    .pushBytes(.init(hex: "34b6c399093e06cf9f0f7f660a1abcfe78fcf7b576f43993208edd9518a0ae9b")!)
                ]
            )
        ],
        serializedTransaction: "0100000000010100010000000000000000000000000000000000000000000000000000000000000000000000ffffffff01e803000000000000015101045102010100000000",
        verifyFlags: "P2SH,WITNESS"
    ),

    // P2WSH with an empty redeem should fail due to empty stack
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "3d4da21b04a67a54c8a58df1c53a0534b0a7f0864fb3d19abd43b8f6934e785f",
                outputIndex: 0,
                amount: 1337,
                scriptOperations: [
                    .zero,
                    .pushBytes(.init(hex: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")!)
                ]
            )
        ],
        serializedTransaction: "020000000001015f784e93f6b843bd9ad1b34f86f0a7b034053ac5f18da5c8547aa6041ba24d3d0000000000ffffffff013905000000000000220020e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855010000000000",
        verifyFlags: "P2SH,WITNESS"
    ),

    // 33 bytes push should be considered a witness scriptPubKey
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 1000,
                scriptOperations: [
                    .constant(16),
                    .pushBytes(.init(hex: "ff25429251b5a84f452230a3c75fd886b7fc5a7865ce4a7bb7a9d7c5be6da3dbff")!)
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffffff01e803000000000000015100000000",
        verifyFlags: "P2SH,WITNESS,DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM"
    ),

    // MARK: - FindAndDelete tests
    // This is a test of FindAndDelete. The first tx is a spend of normal scriptPubKey and the second tx is a spend of bare P2WSH.
    // The redeemScript/witnessScript is CHECKSIGVERIFY <0x30450220487fb382c4974de3f7d834c1b617fe15860828c7f96454490edd6d891556dcc9022100baf95feb48f845d5bfc9882eb6aeefa1bc3790e39f59eaa46ff7f15ae626c53e01>.
    // The signature is <0x30450220487fb382c4974de3f7d834c1b617fe15860828c7f96454490edd6d891556dcc9022100baf95feb48f845d5bfc9882eb6aeefa1bc3790e39f59eaa46ff7f15ae626c53e01> <pubkey>, where the pubkey is obtained through key recovery with sig and the wrong sighash.
    // This is to show that FindAndDelete is applied only to non-segwit scripts.
    // To show that the tests are 'correctly wrong', they should pass by modifying OP_CHECKSIG under `interpreter.cpp` by replacing (sigversion == SigVersion::BASE) with (sigversion != SigVersion::BASE)

    // Non-segwit: wrong sighash (without FindAndDelete) = 1ba1fe3bc90c5d1265460e684ce6774e324f0fabdf67619eda729e64e8b6bc08
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "f18783ace138abac5d3a7a5cf08e88fe6912f267ef936452e0c27d090621c169",
                outputIndex: 7000,
                amount: 200000,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "0c746489e2d83cdbb5b90b432773342ba809c134")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "010000000169c12106097dc2e0526493ef67f21269fe888ef05c7a3a5dacab38e1ac8387f1581b0000b64830450220487fb382c4974de3f7d834c1b617fe15860828c7f96454490edd6d891556dcc9022100baf95feb48f845d5bfc9882eb6aeefa1bc3790e39f59eaa46ff7f15ae626c53e012103b12a1ec8428fc74166926318c15e17408fea82dbb157575e16a8c365f546248f4aad4830450220487fb382c4974de3f7d834c1b617fe15860828c7f96454490edd6d891556dcc9022100baf95feb48f845d5bfc9882eb6aeefa1bc3790e39f59eaa46ff7f15ae626c53e01ffffffff0101000000000000000000000000",
        verifyFlags: "P2SH"
    ),

    // BIP143: wrong sighash (with FindAndDelete) = 71c9cd9b2869b9c70b01b1f0360c148f42dee72297db312638df136f43311f23
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "f18783ace138abac5d3a7a5cf08e88fe6912f267ef936452e0c27d090621c169",
                outputIndex: 7500,
                amount: 200000,
                scriptOperations: [
                    .zero,
                    .pushBytes(.init(hex: "9e1be07558ea5cc8e02ed1d80c0911048afad949affa36d5c3951e3159dbea19")!)
                ]
            )
        ],
        serializedTransaction: "0100000000010169c12106097dc2e0526493ef67f21269fe888ef05c7a3a5dacab38e1ac8387f14c1d000000ffffffff01010000000000000000034830450220487fb382c4974de3f7d834c1b617fe15860828c7f96454490edd6d891556dcc9022100baf95feb48f845d5bfc9882eb6aeefa1bc3790e39f59eaa46ff7f15ae626c53e012102a9d7ed6e161f0e255c10bbfcca0128a9e2035c2c8da58899c54d22d3a31afdef4aad4830450220487fb382c4974de3f7d834c1b617fe15860828c7f96454490edd6d891556dcc9022100baf95feb48f845d5bfc9882eb6aeefa1bc3790e39f59eaa46ff7f15ae626c53e0100000000",
        verifyFlags: "P2SH,WITNESS"
    ),

    // MARK: - This is multisig version of the FindAndDelete tests
    // Script is 2 CHECKMULTISIGVERIFY <sig1> <sig2> DROP 52af4830450220487fb382c4974de3f7d834c1b617fe15860828c7f96454490edd6d891556dcc9022100baf95feb48f845d5bfc9882eb6aeefa1bc3790e39f59eaa46ff7f15ae626c53e0148304502205286f726690b2e9b0207f0345711e63fa7012045b9eb0f19c2458ce1db90cf43022100e89f17f86abc5b149eba4115d4f128bcf45d77fb3ecdd34f594091340c0395960175
    // Signature is 0 <sig1> <sig2> 2 <key1> <key2>
    // Should pass by replacing (sigversion == SigVersion::BASE) with (sigversion != SigVersion::BASE) under OP_CHECKMULTISIG

    // Non-segwit: wrong sighash (without FindAndDelete) = 4bc6a53e8e16ef508c19e38bba08831daba85228b0211f323d4cb0999cf2a5e8
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "9628667ad48219a169b41b020800162287d2c0f713c04157e95c484a8dcb7592",
                outputIndex: 7000,
                amount: 200000,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "5748407f5ca5cdca53ba30b79040260770c9ee1b")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000019275cb8d4a485ce95741c013f7c0d28722160008021bb469a11982d47a662896581b0000fd6f01004830450220487fb382c4974de3f7d834c1b617fe15860828c7f96454490edd6d891556dcc9022100baf95feb48f845d5bfc9882eb6aeefa1bc3790e39f59eaa46ff7f15ae626c53e0148304502205286f726690b2e9b0207f0345711e63fa7012045b9eb0f19c2458ce1db90cf43022100e89f17f86abc5b149eba4115d4f128bcf45d77fb3ecdd34f594091340c039596015221023fd5dd42b44769c5653cbc5947ff30ab8871f240ad0c0e7432aefe84b5b4ff3421039d52178dbde360b83f19cf348deb04fa8360e1bf5634577be8e50fafc2b0e4ef4c9552af4830450220487fb382c4974de3f7d834c1b617fe15860828c7f96454490edd6d891556dcc9022100baf95feb48f845d5bfc9882eb6aeefa1bc3790e39f59eaa46ff7f15ae626c53e0148304502205286f726690b2e9b0207f0345711e63fa7012045b9eb0f19c2458ce1db90cf43022100e89f17f86abc5b149eba4115d4f128bcf45d77fb3ecdd34f594091340c0395960175ffffffff0101000000000000000000000000",
        verifyFlags: "P2SH"
    ),

    // BIP143: wrong sighash (with FindAndDelete) = 17c50ec2181ecdfdc85ca081174b248199ba81fff730794d4f69b8ec031f2dce
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "9628667ad48219a169b41b020800162287d2c0f713c04157e95c484a8dcb7592",
                outputIndex: 7500,
                amount: 200000,
                scriptOperations: [
                    .zero,
                    .pushBytes(.init(hex: "9b66c15b4e0b4eb49fa877982cafded24859fe5b0e2dbfbe4f0df1de7743fd52")!)
                ]
            )
        ],
        serializedTransaction: "010000000001019275cb8d4a485ce95741c013f7c0d28722160008021bb469a11982d47a6628964c1d000000ffffffff0101000000000000000007004830450220487fb382c4974de3f7d834c1b617fe15860828c7f96454490edd6d891556dcc9022100baf95feb48f845d5bfc9882eb6aeefa1bc3790e39f59eaa46ff7f15ae626c53e0148304502205286f726690b2e9b0207f0345711e63fa7012045b9eb0f19c2458ce1db90cf43022100e89f17f86abc5b149eba4115d4f128bcf45d77fb3ecdd34f594091340c03959601010221023cb6055f4b57a1580c5a753e19610cafaedf7e0ff377731c77837fd666eae1712102c1b1db303ac232ffa8e5e7cc2cf5f96c6e40d3e6914061204c0541cb2043a0969552af4830450220487fb382c4974de3f7d834c1b617fe15860828c7f96454490edd6d891556dcc9022100baf95feb48f845d5bfc9882eb6aeefa1bc3790e39f59eaa46ff7f15ae626c53e0148304502205286f726690b2e9b0207f0345711e63fa7012045b9eb0f19c2458ce1db90cf43022100e89f17f86abc5b149eba4115d4f128bcf45d77fb3ecdd34f594091340c039596017500000000",
        verifyFlags: "P2SH,WITNESS"
    ),

    // MARK: - SCRIPT_VERIFY_CONST_SCRIPTCODE tests
    // All transactions are copied from OP_CODESEPARATOR tests in tx_valid.json

    // Test that SignatureHash() removes OP_CODESEPARATOR with FindAndDelete()
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "bc7fd132fcf817918334822ee6d9bd95c889099c96e07ca2c1eb2cc70db63224",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .codeSeparator,
                    .pushBytes(.init(hex: "038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041")!),
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000012432b60dc72cebc1a27ce0969c0989c895bdd9e62e8234839117f8fc32d17fbc000000004a493046022100a576b52051962c25e642c0fd3d77ee6c92487048e5d90818bcf5b51abaccd7900221008204f8fb121be4ec3b24483b1f92d89b1b0548513a134e345c5442e86e8617a501ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "83e194f90b6ef21fa2e3a365b63794fb5daa844bdc9b25de30899fcfe7b01047",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .codeSeparator,
                    .codeSeparator,
                    .pushBytes(.init(hex: "038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041")!),
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000014710b0e7cf9f8930de259bdc4b84aa5dfb9437b665a3e3a21ff26e0bf994e183000000004a493046022100a166121a61b4eeb19d8f922b978ff6ab58ead8a5a5552bf9be73dc9c156873ea02210092ad9bc43ee647da4f6652c320800debcf08ec20a094a0aaf085f63ecb37a17201ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE"
    ),

    // Hashed data starts at the CODESEPARATOR
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "326882a7f22b5191f1a0cc9962ca4b878cd969cf3b3a70887aece4d801a0ba5e",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041")!),
                    .codeSeparator,
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000015ebaa001d8e4ec7a88703a3bcf69d98c874bca6299cca0f191512bf2a7826832000000004948304502203bf754d1c6732fbf87c5dcd81258aefd30f2060d7bd8ac4a5696f7927091dad1022100f5bcb726c4cf5ed0ed34cc13dadeedf628ae1045b7cb34421bc60b89f4cecae701ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE"
    ),

    // But only if execution has reached it
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "a955032f4d6b0c9bfe8cad8f00a8933790b9c1dc28c82e0f48e75b35da0e4944",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041")!),
                    .checkSigVerify,
                    .codeSeparator,
                    .pushBytes(.init(hex: "038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041")!),
                    .checkSigVerify,
                    .codeSeparator,
                    .constant(1)
                ]
            ),
        ],
        serializedTransaction: "010000000144490eda355be7480f2ec828dcc1b9903793a8008fad8cfe9b0c6b4d2f0355a900000000924830450221009c0a27f886a1d8cb87f6f595fbc3163d28f7a81ec3c4b252ee7f3ac77fd13ffa02203caa8dfa09713c8c4d7ef575c75ed97812072405d932bd11e6a1593a98b679370148304502201e3861ef39a526406bad1e20ecad06be7375ad40ddb582c9be42d26c3a0d7b240221009d0a3985e96522e59635d19cc4448547477396ce0ef17a58e7d74c3ef464292301ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE"
    ),

    // CODESEPARATOR in an unexecuted IF block is still invalid
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "a955032f4d6b0c9bfe8cad8f00a8933790b9c1dc28c82e0f48e75b35da0e4944",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .if,
                    .codeSeparator,
                    .endIf,
                    .pushBytes(.init(hex: "0378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c71")!),
                    .checkSigVerify,
                    .codeSeparator,
                    .constant(1)
                ]
            ),
        ],
        serializedTransaction: "010000000144490eda355be7480f2ec828dcc1b9903793a8008fad8cfe9b0c6b4d2f0355a9000000004a48304502207a6974a77c591fa13dff60cabbb85a0de9e025c09c65a4b2285e47ce8e22f761022100f0efaac9ff8ac36b10721e0aae1fb975c90500b50c56e8a0cc52b0403f0425dd0100ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE"
    ),

    // CODESEPARATOR in an executed IF block is invalid
    // This tx is 100% equal to the one in valid, including flags (included vs excluded)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "a955032f4d6b0c9bfe8cad8f00a8933790b9c1dc28c82e0f48e75b35da0e4944",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .if,
                    .codeSeparator,
                    .endIf,
                    .pushBytes(.init(hex: "0378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c71")!),
                    .checkSigVerify,
                    .codeSeparator,
                    .constant(1)
                ]
            ),
        ],
        serializedTransaction: "010000000144490eda355be7480f2ec828dcc1b9903793a8008fad8cfe9b0c6b4d2f0355a9000000004a483045022100fa4a74ba9fd59c59f46c3960cf90cbe0d2b743c471d24a3d5d6db6002af5eebb02204d70ec490fd0f7055a7c45f86514336e3a7f03503dacecabb247fc23f15c83510151ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE"
    ),

    // Using CHECKSIG with signatures in scriptSigs will trigger FindAndDelete, which is invalid
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "ccf7f4053a02e653c36ac75c891b7496d0dc5ce5214f6c913d9cf8f1329ebee0",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "ee5a6aa40facefb2655ac23c0c28c57c65c41f9b")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "0100000001e0be9e32f1f89c3d916c4f21e55cdcd096741b895cc76ac353e6023a05f4f7cc00000000d86149304602210086e5f736a2c3622ebb62bd9d93d8e5d76508b98be922b97160edc3dcca6d8c47022100b23c312ac232a4473f19d2aeb95ab7bdf2b65518911a0d72d50e38b5dd31dc820121038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ac4730440220508fa761865c8abd81244a168392876ee1d94e8ed83897066b5e2df2400dad24022043f5ee7538e87e9c6aef7ef55133d3e51da7cc522830a9c4d736977a76ef755c0121038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE"
    ),

    // OP_CODESEPARATOR in scriptSig is invalid
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "10c9f0effe83e97f80f067de2b11c6a00c3088a4bce42c5ae761519af9306f3c",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "ee5a6aa40facefb2655ac23c0c28c57c65c41f9b")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000013c6f30f99a5161e75a2ce4bca488300ca0c6112bde67f0807fe983feeff0c91001000000e608646561646265656675ab61493046022100ce18d384221a731c993939015e3d1bcebafb16e8c0b5b5d14097ec8177ae6f28022100bcab227af90bab33c3fe0a9abfee03ba976ee25dc6ce542526e9b2e56e14b7f10121038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ac493046022100c3b93edcc0fd6250eb32f2dd8a0bba1754b0f6c3be8ed4100ed582f3db73eba2022100bf75b5bd2eff4d6bf2bda2e34a40fcc07d4aa3cf862ceaa77b47b81eff829f9a01ab21038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE"
    ),

    // Again, FindAndDelete() in scriptSig
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "6056ebd549003b10cbbd915cea0d82209fe40b8617104be917a26fa92cbe3d6f",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "ee5a6aa40facefb2655ac23c0c28c57c65c41f9b")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000016f3dbe2ca96fa217e94b1017860be49f20820dea5c91bdcb103b0049d5eb566000000000fd1d0147304402203989ac8f9ad36b5d0919d97fa0a7f70c5272abee3b14477dc646288a8b976df5022027d19da84a066af9053ad3d1d7459d171b7e3a80bc6c4ef7a330677a6be548140147304402203989ac8f9ad36b5d0919d97fa0a7f70c5272abee3b14477dc646288a8b976df5022027d19da84a066af9053ad3d1d7459d171b7e3a80bc6c4ef7a330677a6be548140121038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ac47304402203757e937ba807e4a5da8534c17f9d121176056406a6465054bdd260457515c1a02200f02eccf1bec0f3a0d65df37889143c2e88ab7acec61a7b6f5aa264139141a2b0121038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE"
    ),

    // That also includes ahead of the opcode being executed.
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "5a6b0021a6042a686b6b94abc36b387bef9109847774e8b1e51eb8cc55c53921",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "ee5a6aa40facefb2655ac23c0c28c57c65c41f9b")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000012139c555ccb81ee5b1e87477840991ef7b386bc3ab946b6b682a04a621006b5a01000000fdb40148304502201723e692e5f409a7151db386291b63524c5eb2030df652b1f53022fd8207349f022100b90d9bbf2f3366ce176e5e780a00433da67d9e5c79312c6388312a296a5800390148304502201723e692e5f409a7151db386291b63524c5eb2030df652b1f53022fd8207349f022100b90d9bbf2f3366ce176e5e780a00433da67d9e5c79312c6388312a296a5800390121038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f2204148304502201723e692e5f409a7151db386291b63524c5eb2030df652b1f53022fd8207349f022100b90d9bbf2f3366ce176e5e780a00433da67d9e5c79312c6388312a296a5800390175ac4830450220646b72c35beeec51f4d5bc1cbae01863825750d7f490864af354e6ea4f625e9c022100f04b98432df3a9641719dbced53393022e7249fb59db993af1118539830aab870148304502201723e692e5f409a7151db386291b63524c5eb2030df652b1f53022fd8207349f022100b90d9bbf2f3366ce176e5e780a00433da67d9e5c79312c6388312a296a580039017521038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE"
    ),

    // FindAndDelete() in redeemScript
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "b5b598de91787439afd5938116654e0b16b7a0d0f82742ba37564219c5afcbf9",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "f6f365c40f0739b61de827a44751e5e99032ed8f")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "ab9805c6d57d7070d9a42c5176e47bb705023e6b67249fb6760880548298e742",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "d8dacdadb7462ae15cd906f1878706d0da8660e6")!),
                    .equal
                ]
            ),
        ],
        serializedTransaction: "0100000002f9cbafc519425637ba4227f8d0a0b7160b4e65168193d5af39747891de98b5b5000000006b4830450221008dd619c563e527c47d9bd53534a770b102e40faa87f61433580e04e271ef2f960220029886434e18122b53d5decd25f1f4acb2480659fea20aabd856987ba3c3907e0121022b78b756e2258af13779c1a1f37ea6800259716ca4b7f0b87610e0bf3ab52a01ffffffff42e7988254800876b69f24676b3e0205b77be476512ca4d970707dd5c60598ab00000000fd260100483045022015bd0139bcccf990a6af6ec5c1c52ed8222e03a0d51c334df139968525d2fcd20221009f9efe325476eb64c3958e4713e9eefe49bf1d820ed58d2112721b134e2a1a53034930460221008431bdfa72bc67f9d41fe72e94c88fb8f359ffa30b33c72c121c5a877d922e1002210089ef5fc22dd8bfc6bf9ffdb01a9862d27687d424d1fefbab9e9c7176844a187a014c9052483045022015bd0139bcccf990a6af6ec5c1c52ed8222e03a0d51c334df139968525d2fcd20221009f9efe325476eb64c3958e4713e9eefe49bf1d820ed58d2112721b134e2a1a5303210378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c71210378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c7153aeffffffff01a08601000000000017a914d8dacdadb7462ae15cd906f1878706d0da8660e68700000000",
        verifyFlags: "P2SH,CONST_SCRIPTCODE"
    ),

    // FindAndDelete() in bare CHECKMULTISIG
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "ceafe58e0f6e7d67c0409fbbf673c84c166e3c5d3c24af58f7175b18df3bb3db",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "f6f365c40f0739b61de827a44751e5e99032ed8f")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "ceafe58e0f6e7d67c0409fbbf673c84c166e3c5d3c24af58f7175b18df3bb3db",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .constant(2),
                    .pushBytes(.init(hex: "3045022015bd0139bcccf990a6af6ec5c1c52ed8222e03a0d51c334df139968525d2fcd20221009f9efe325476eb64c3958e4713e9eefe49bf1d820ed58d2112721b134e2a1a5303")!),
                    .pushBytes(.init(hex: "0378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c71")!),
                    .pushBytes(.init(hex: "0378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c71")!),
                    .constant(3),
                    .checkMultiSig
                ]
            ),
        ],
        serializedTransaction: "0100000002dbb33bdf185b17f758af243c5d3c6e164cc873f6bb9f40c0677d6e0f8ee5afce000000006b4830450221009627444320dc5ef8d7f68f35010b4c050a6ed0d96b67a84db99fda9c9de58b1e02203e4b4aaa019e012e65d69b487fdf8719df72f488fa91506a80c49a33929f1fd50121022b78b756e2258af13779c1a1f37ea6800259716ca4b7f0b87610e0bf3ab52a01ffffffffdbb33bdf185b17f758af243c5d3c6e164cc873f6bb9f40c0677d6e0f8ee5afce010000009300483045022015bd0139bcccf990a6af6ec5c1c52ed8222e03a0d51c334df139968525d2fcd20221009f9efe325476eb64c3958e4713e9eefe49bf1d820ed58d2112721b134e2a1a5303483045022015bd0139bcccf990a6af6ec5c1c52ed8222e03a0d51c334df139968525d2fcd20221009f9efe325476eb64c3958e4713e9eefe49bf1d820ed58d2112721b134e2a1a5303ffffffff01a0860100000000001976a9149bc0bbdd3024da4d0c38ed1aecf5c68dd1d3fa1288ac00000000",
        verifyFlags: "CONST_SCRIPTCODE"
    ),
]
