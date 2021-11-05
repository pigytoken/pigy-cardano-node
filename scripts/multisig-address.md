



# How-to create multi-signature scripts on cardano

**Multi signature scripts can help us to secure certain addresses by different individuals.**

Notice: This how-to is based on our docker node project.

Which possibilities there are you can read here:

https://github.com/input-output-hk/cardano-node/blob/master/doc/reference/simple-scripts.md

In our example there are 3 persons (Bob, Alice and John) of which at least 2 persons have to confirm the transaction. Bob wants to send a transaction from a multisig address and asks John to confirm this transaction. Only then the transaction should be executed.

So we will choose Type "atLeast" as script type.

We assume that you sign your transactions with an air-gapped offline machine.

[Generate Key hashes and scripts](#Generate-Key-hashes-and-scripts)

[Create a Multi Signature Transaction](#Now-we-create-a-Multi-Signature-Transaction)

[Witnessing and Signing the Transaction](#Witnessing-and-Signing-the-Transaction)

[How to send Native Tokens with MultiSig](#How-to-send-Native-Tokens-with-MultiSig)

## Generate Key hashes and scripts

**Each of the possible signers must generate a payment key**:

```bash
# On Air-gapped
#BOB:
cardano-cli address key-gen \
  --verification-key-file payment1.vkey \
  --signing-key-file payment1.skey

#ALICE:
cardano-cli address key-gen \
  --verification-key-file payment2.vkey \
  --signing-key-file payment2.skey

#JOHN:
cardano-cli address key-gen \
  --verification-key-file payment3.vkey \
  --signing-key-file payment3.skey
```

| NOTE: | Caution: These keys should be stored very carefully. We recommend to use at least 5 signing keys and to set the number of required signatures to 3 signing keys. |
| ----- | ------------------------------------------------------------ |

Caution: These keys should be stored very carefully. We recommend to use at least 5 signing keys and to set the number of required signatures to 3 signing keys.

**Bob creates now the building scripts**

```bash
# On Air-gapped - Bob
touch multisig.json

nano multisig.json # or vim

# Add example JSON Object to the json file
{
    "type": "atLeast",
	"required": 2,
    "scripts": [
        {
            "keyHash": "key 1",
            "type": "sig"
        },
        {
            "keyHash": "key 2",
            "type": "sig"
        },
        {
            "keyHash": "key 3",
            "type": "sig"
        }
    ]
}
```

**Creating Key Hashes**

Bob, Alice and John must now encrypt their keys.

```bash
# On Air-gapped Bob, Alice, John

cardano-cli address key-hash --payment-verification-key-file payment1.vkey

# or payment2.vkey..

# Output: 0394328476236523587f238hj8324823842323423iuf
```

Now Alice and John have to send their key hashes to Bob. Bob now enters them into the multisig.json file:

```bash
# On Air-gapped - Bob
{
    "type": "atLeast",
	"required": 2,
    "scripts": [
        {
            "keyHash": "0394328476236523587f238hj8324823842323423iuf", 
            "type": "sig"
        },
        {
            "keyHash": "523587f238hj039432847623683248238423234234zh",
            "type": "sig"
        },
        {
            "keyHash": "03943284j83248238476236523587f238h23234234rf",
            "type": "sig"
        }
    ]
}
```

**Bob can now use the key hashes to create a multi-signature address.**

```bash
# on airgapped - Bob

cardano-cli address build \
  --payment-script-file multisig.json \
  --testnet-magic 1097911063 \
  --out-file multisig.addr
```

**Now copy the "multisig.addr" and "multisig.json" file to the Hot Environment!**

On testnet send for example 30 tADA to the Multi Signature Address.

Show address: 

```bash
cat multisig.addr
```

Check if the transfer has arrived:

```bash
cardano-cli query utxo --address $(cat multisig.addr) --testnet-magic 1097911063
```

## Now we create a Multi Signature Transaction

Now create a new protocol parameter file:

```bash
# On Hot Environment - Bob
cardano-cli query protocol-parameters \
    --testnet-magic 1097911063 \
    --out-file params.json
```

Find the "tip" of the blockchain now so we can set the "invalid-hereafter" properly:

```bash
# On Hot Environment - Bob
currentSlot=$(cardano-cli query tip --testnet-magic 1097911063 | jq -r '.slot')
echo Current Slot: $currentSlot

# Output example
Current Slot: 39095374
```

We would now like to send 20 tADA to one address:

```bash
# On Hot Environment - Bob
amountToSend=20000000
echo amountToSend: $amountToSend

# Output
20000000 # 20 tADA
```

Now set the destination address:

```bash
destinationAddress=addr_test1qr0a6p56c3tx3en9ya6gnz4ku0hrl97uepre49le965rc3f2ucalwdqpj8ylgr6cvyqkttpz0r04flj76u3h694ct76sc63rsf
echo destinationAddress: $destinationAddress
```

We now push all required data into variables:

```bash
# On Hot Environment - Bob
cardano-cli query utxo \
    --address $(cat multisig.addr) \
    --testnet-magic 1097911063 > fullUtxo.out

tail -n +3 fullUtxo.out | sort -k3 -nr > balance.out

cat balance.out

tx_in=""
total_balance=0
while read -r utxo; do
    in_addr=$(awk '{ print $1 }' <<< "${utxo}")
    idx=$(awk '{ print $2 }' <<< "${utxo}")
    utxo_balance=$(awk '{ print $3 }' <<< "${utxo}")
    total_balance=$((${total_balance}+${utxo_balance}))
    echo TxHash: ${in_addr}#${idx}
    echo ADA: ${utxo_balance}
    tx_in="${tx_in} --tx-in ${in_addr}#${idx}"
done < balance.out
txcnt=$(cat balance.out | wc -l)
echo Total ADA balance: ${total_balance}
echo Number of UTXOs: ${txcnt}

# Output example
TxHash: 279c472d1b84b3be214e44bd6b79a3ce2c19c4d8c5c133148a1465ff54ddb774#0
ADA: 20000000
Total ADA balance: 20000000
Number of UTXOs: 1

```

Now we execute the "build-raw" command:

NOTE: If you would send Native Tokens than read [How to send Native Tokens with MultiSig](#How-to-send-Native-Tokens-with-MultiSig)

```bash
# On Hot Environment - Bob
cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat multisig.addr)+0 \
    --tx-out ${destinationAddress}+0 \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
	--tx-in-script-file multisig.json \
    --fee 0 \
    --out-file tx.tmp
```

Now we calculate the transaction fees:

```bash
# On Hot Environment - Bob
fee=$(cardano-cli transaction calculate-min-fee \
    --tx-body-file tx.tmp \
    --tx-in-count ${txcnt} \
    --tx-out-count 2 \
    --testnet-magic 1097911063 \
    --witness-count 2 \
    --protocol-params-file params.json | awk '{ print $1 }')
echo fee: $fee

# Output example
fee: 175665
```

Note: Set --witness-count to the number of witnesses. If you have defined 3 in the MultiSig script and set the min. witnesses to 2, set --witness-count to `--witness-count 2`.

We calculate the change output:

```bash
# On Hot Environment - Bob
txOut=$((${total_balance}-${fee}-${amountToSend}))
echo Change Output: ${txOut}

# Output example
Change Output: 79824335 
```

Now we create the transaction:

```bash
# On Hot Environment - Bob
cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat multisig.addr)+${txOut} \
    --tx-out ${destinationAddress}+${amountToSend} \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
	--tx-in-script-file multisig.json \
    --fee ${fee} \
    --out-file multisig.raw
```

## Witnessing and Signing the Transaction

In our example, at least 2 people need to confirm the transaction. Let's assume that Bob and John are these persons.

Bob now needs to send via a secure path John the build-raw and multisig script file he just created (**multisig.raw**).

You can Copy the "multisig.raw to your Host with:

```bash
# On host
docker cp cardano-node-1.30.1:/opt/data/multisig.raw ./<PATH_ON_YOUR_HOST>
```

We use the Mantra tools to check that we are signing the right transaction. **Credits goes to [functionally](https://github.com/functionally/mantis) for this create tool.**

Now go to your Air-gapped machine and check if the transaction is correct:

```bash
# On Air-gapped Environment

mantra info-txbody multisig.raw

# Output
Transaction body file: multisig.raw
"a88a90d3d9cb950cb610cd54f0a5f4621d1e51fc41466382c17f5c88130224c5"
ShelleyTxBody ShelleyBasedEraMary (TxBodyConstr TxBodyRaw {inputs = fromList [TxInCompact (TxId {_unTxId = SafeHash "279c472d1b84b3be214e44bd6b79a3ce2c19c4d8c5c133148a1465ff54ddb774"}) 0], outputs = StrictSeq {fromStrict = fromList [(Addr Testnet (ScriptHashObj (ScriptHash "0082d29e38fa9e18e9977875a55aa808cd7b8fbc0f26debdbcf8d9cf")) StakeRefNull,Value 12819847 (fromList [])),(Addr Testnet (KeyHashObj (KeyHash "dfdd069ac45668e6652774898ab6e3ee3f97dcc8479a97f92ea83c45")) (StakeRefBase (KeyHashObj (KeyHash "2ae63bf7340191c9f40f58610165ac2278df54fe5ed7237d16b85fb5"))),Value 7000000 (fromList []))]}, certs = StrictSeq {fromStrict = fromList []}, wdrls = Wdrl {unWdrl = fromList []}, txfee = Coin 180153, vldt = ValidityInterval {invalidBefore = SNothing, invalidHereafter = SJust (SlotNo 39532164)}, update = SNothing, adHash = SNothing, mint = Value 0 (fromList [])}) [TimelockConstr MOfN 2 (StrictSeq {fromStrict = fromList [TimelockConstr Signature (KeyHash "ce46c3bcc5b9ef247adc5a0131a143176f1533047ead353fe65cf4c2"),TimelockConstr Signature (KeyHash "c050b1179a4c2919463b9631b30276928564fb614c8f59e6da39d00b"),TimelockConstr Signature (KeyHash "db867d177470b2887b8560245a09ec1837dfa6fdd6a289a926dcd890")]})] TxBodyNoScriptData Nothing TxScriptValidityNone
```

The first ID is the Transactions ID and one of the "Value" is the quantity we are sending.

```bash
mantra info-txbody multisig.raw | grep -oP 'Value\D\d+'

# Output
Value 12819847
Value 7000000 # 7000000 / 1000000 = 7 ADA
Value 0
```

If all is fine with multisig.raw file than sign now the transaction:

```bash
# On Air-gapped Environment

# Bob
cardano-cli transaction witness \
  --testnet-magic 1097911063 \
  --tx-body-file multisig.raw \
  --signing-key-file payment1.skey \
  --out-file "key1_multisig.witness"
  
# John
cardano-cli transaction witness \
  --testnet-magic 1097911063 \
  --tx-body-file multisig.raw \
  --signing-key-file payment3.skey \
  --out-file "key3_multisig.witness"
```

John must now send his signed file "Key3_multisig.witness" to Bob.

Bob transfer the ".witness" files in to the container:

```bash
# On host
docker cp ./key1_multisig.witness cardano-node-1.30.1:/opt/data
docker cp ./key3_multisig.witness cardano-node-1.30.1:/opt/data
```

If you use our docker project you can copy the "mutlisig.raw" file from the running container

Bob can now put assemble the witness transaction:

```bash
# Hot Environment - Bob
cardano-cli transaction assemble \
  --tx-body-file multisig.raw \
  --witness-file "key1_multisig.witness" \
  --witness-file "key3_multisig.witness" \
  --out-file multisig.signed
```

Execute transaction:

```bash
# Hot Environment - Bob
cardano-cli transaction submit \
  --tx-file multisig.signed \
  --testnet-magic 1097911063
```

Check if the transaction has arrived:

```bash
# Check if the transaction arrived
cardano-cli query utxo \
    --address $destinationAddress \
    --testnet-magic 1097911063
```

It may take a moment until the transaction is displayed.

## How to send Native Tokens with MultiSig

To send Native Tokens, only the command `cardano-cli transaction build-raw` must be revised.

```bash
# On Hot environment

cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat multisig.addr)+0 \
    --tx-out ${destinationAddress}+${amountToSend}+"<AMOUNT_OF_TOKEN> <TOKEN_POLICYID>" \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
    --tx-in-script-file multisig.json \
    --fee 0 \
    --out-file tx.tmp
```

```bash
# On Hot environment - after fee calculation

cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat multisig.addr)+${txOut} \
    --tx-out ${destinationAddress}+${amountToSend}+"<AMOUNT_OF_TOKEN> <TOKEN_POLICYID>" \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
    --tx-in-script-file multisig.json \
    --fee ${fee} \
    --out-file multisig.raw
```

Now confirm the transaction as usual and send it.
