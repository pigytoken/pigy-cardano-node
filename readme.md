# Super Simple Cardano-Node with Docker

You will find here a simple Cardano-Node setup without bells and whistles.

**System requirements:**

Min. Memory: 8GB

System: this project is for x86_64 systems (If you have an Raspberry Pi or an new  Mac M1 with ARM CPU you need the aarch64 package's for GHC)

**Docker:**

How-to [Ubuntu 20.04](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04)

How-to [Windows](https://docs.docker.com/desktop/windows/install/) we recommended the [WSL2](https://www.omgubuntu.co.uk/how-to-install-wsl2-on-windows-10) backend

**Docker-compose:**

How-to [Ubuntu 20.04](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-20-04)
*Under Windows the docker-compose is integrated in the Docker Installation.*

## How-to start

Once you have prepared your Docker environment, we can now customize our Docker project.

There are two ways to operate the node:

1. testnet `--testnet-magic 1097911063` 
2. mainnet `--mainnet`

Let's assume we want to run the node on the Tesnet. Except for a few changes, the process is always the same.

### Source download and checkout select

First we create the user `dockeruser` with the home folder  `srv/docker` 

```bash
adduser --home /srv/docker dockeruser
```

Add Docker user to Docker group

```bash
usermod -aG docker dockeruser
```

Add Dockeruser to the sudo group

```bash
usermod -aG sudo dockeruser
```

Now create a folder under `/srv/docker`

```bash
mkdir -p cardano-node-<VERSION>
```

Go to the folder and clone the project:

```bash
cd /srv/docker/cardano-node-<VERSION>
```

```bash
git clone https://github.com/pigytoken/ss-cardano-node.git .
```

Now check which branch you are currently in:

```bash
git status

# Output example
❯ git status
On branch main
```

This is fine if you need the latest branch, if you want to be on the safe side you can use git branch -a to list all local and remote branches:

```bash
git pull
git branch -a

# Output example
  1.30.1
* main
  remotes/origin/main
```

We now want to use the branch 1.30.1 for this we have to check it out depending on whether it is local or in the remote git the command differs slightly here.

Local:

```bash
git checkout 1.30.1
```

Remote:

```bash
git checkout --track remotes/origin/main # example
```

We are now in branch 1.30.1 and can start working on the Docker project.

### Customize project

Open the docker-compose.yml with an editor of your choice:

```bash
nano docker-compose.yml
```

Adjust the following settings for the mainnet or for the testnet:

```yaml
  environment:
    - NETWORK=testnet #testnet or mainnet

  entrypoint: [
    
    --topology /etc/config/testnet-topology.json \ # testnet-topology.json or mainnet-topology.json
    --config /etc/config/testnet-config.json" # testnet-config.json or mainnet-config.json
```

Speichere nun die Datei ab. Strg + x

### Start project

To build and start the Docker container you have to execute the following command:

```bash
docker-compose up -d
```

You can see if the container has been started correctly with:

```bash
docker ps

# output
CONTAINER ID   IMAGE                  COMMAND                  CREATED        STATUS          PORTS                    NAMES
0f7ff791fabe   cardano-node:v1.30.1   "bash -c 'sleep 10 &…"   18 hours ago   Up 51 minutes   0.0.0.0:3001->3001/tcp   cardano-node-1.30.1
```

If you want to see the log you can do this with the following command:

```bash
docker-compose logs -f (-f for tail)
```

If you want to know now what is the sync status of your node you can execute the following command:

```bash
docker exec <CONTAINER-NAME>  bash -c "cardano-cli query tip --testnet-magic 1097911063"

# Output example
{
    "epoch": 160,
    "hash": "4416eeaffb8dfc5ea5f41efb645828ef8be56bf3ba97a4e95e863fb3b1cde240",
    "slot": 39079026,
    "block": 2968183,
    "era": "Alonzo",
    "syncProgress": "100.00"
}
```

If there are problems you can simply restart the node. Just go to your /srv/docker/<NODE-FOLDER> folder and execute the following command:

```bash
docker-compose restart
or
docker-compose down
docker-compose up -d
```

## How to setup air-gapped-machine

So that we do not keep our private keys in the public node we need an offline machine. It doesn't matter if this is an old laptop or a Raspberry PI. The only thing it needs is the current cardano-cli binaries.

*Attention. An airgapped machine is not a VM. An airgapped machine is always about absolute security and must therefore never be connected to the Internet. It is best to use a portable system on a boot stick.*

***I recommend that you first familiarize yourself with everything in the test network before performing transactions in the main network. We do not assume any liability!***

How-to create a Ubuntu USB Stick:

https://www.howtogeek.com/howto/14912/create-a-persistent-bootable-ubuntu-usb-flash-drive/

**Copy cardano-cli binarys**

Copy your "cardano-cli" Binarys to a USB Stick:

```bash
docker cp cardano-node-1.30.1:/usr/local/bin/cardano-cli /<PATH_TO_YOUR_USBSTICK-FOLDER>
```

Create a folder for your cardano-cli on your air gapped machine and make it known to the system

```bash
echo export NODE_HOME=$HOME/cardano-cli >> $HOME/.bashrc
echo PATH="$NODE_HOME:$PATH" >> $HOME/.bashrc
source $HOME/.bashrc
mkdir -p $NODE_HOME
mkdir -p $HOME/keys
```

Now copy the "cardano-cli" binary file into the folder you just created:

```bash
cp <PATH_TO_USB_STICK>/cardano-cli $NODE_HOME/cardano-cli/

chmod +x cardano-cli
```

Check if your system finds the cardano-cli:

```bash
cardano-cli --version

# output
cardano-cli 1.30.1 - linux-x86_64 - ghc-8.10
git rev 0fb43f4e3da8b225f4f86557aed90a183981a64f
```

## Make a simple transaction

Now we can start with the creation of the keys. There are several ways to create them. If you run a Stake Pool we recommend that you do not use this variant and rather familiarize yourself with the creation of cold keys and KES certificate.

*Here are a few related links:*

*https://docs.cardano.org/getting-started/guidelines-for-large-spos#mainrecommendations*

*https://iohk.zendesk.com/hc/en-us/articles/900001209326-Node-s-operational-certificate-and-KES-period-stake-pools-*

**Let's get started.**

*Attention! The only thing you need on the air-gapped machine is the matching version of the cardano-cli.

First we create the key pairs `payment.skey` and`payment.vkey`

```bash
# On air-gapped machine

cardano-cli address key-gen \
	--verification-key-file payment.vkey \
	--signing-key-file payment.skey
```

Now create your payment address:

```bash
# On air-gapped machine

cardano-cli address build \
	--payment-verification-key-file payment.vkey \
	--out-file payment.addr \
	--testnet-magic 1097911063
```

**Copy your `payment.addr` to your hot environment**.

```bash
docker cp <PATH_TO_FOLDER>payment.addr cardano-node-1.30.1:/opt/data
```

Now we continue working in the container. To do this, we log in to it:

```bash
docker exec -it cardano-node-1.30.1 bash
```

You can display your payment address with cat:

```bash
cd /opt/data/
echo "$(cat payment.addr)"
```

**Pay yourself some ADA (Mainnet) or tADA (Testnet) money**!

tADA for testnet you get here:

https://testnets.cardano.org/en/testnets/cardano/tools/faucet/

Do you want to look at your balance:

```bash
cardano-cli query utxo \
    --address $(cat payment.addr) \
    --testnet-magic 1097911063

# Output with no funded address
                           TxHash                                 TxIx        Amount
--------------------------------------------------------------------------------------
a17d4cdadbb8cc35b6914a9dce40ac849830552e38dfe19d4f9951656a9ef86a     0        100000000 lovelace + TxOutDatumHashNone
```

1 ADA = 1.000.000 Lovelaces.

Now create a new protocol parameter file:

```bash
cardano-cli query protocol-parameters \
    --testnet-magic 1097911063 \
    --out-file params.json
```

Find the "tip" of the blockchain now so we can set the "invalid-hereafter" properly:

```bash
currentSlot=$(cardano-cli query tip --testnet-magic 1097911063 | jq -r '.slot')
echo Current Slot: $currentSlot

# Output
Current Slot: 39095374
```

We would now like to send 20 tADA to one address:

```bash
amountToSend=20000000
echo amountToSend: $amountToSend

# Output
20000000 # 20 tADA
```

Now set the destination address:

```bash
destinationAddress=addr_test1qzr8qgh6x5ml3y7u52eph2t5m2pumfpxsduz7q26ghe9zap2ucalwdqpj8ylgr6cvyqkttpz0r04flj76u3h694ct76sm8zdgk
echo destinationAddress: $destinationAddress
```

Now we look for the UTXOs and the balance:

```bash
cardano-cli query utxo \
    --address $(cat payment.addr) \
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

# Output
TxHash: a17d4cdadbb8cc35b6914a9dce40ac849830552e38dfe19d4f9951656a9ef86a#0
ADA: 100000000
Total ADA balance: 100000000
Number of UTXOs: 1
```

Now we execute the "build-raw" command:

```bash
cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat payment.addr)+0 \
    --tx-out ${destinationAddress}+0 \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
    --fee 0 \
    --out-file tx.tmp
```

Now we calculate the transaction fees:

```bash
fee=$(cardano-cli transaction calculate-min-fee \
    --tx-body-file tx.tmp \
    --tx-in-count ${txcnt} \
    --tx-out-count 2 \
    --testnet-magic 1097911063 \
    --witness-count 1 \
    --byron-witness-count 0 \
    --protocol-params-file params.json | awk '{ print $1 }')
echo fee: $fee

# Output
fee: 175665
```

We calculate the change output:

```bash
txOut=$((${total_balance}-${fee}-${amountToSend}))
echo Change Output: ${txOut}

# Output
Change Output: 79824335
```

Now we create the transaction:

```bash
cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat payment.addr)+${txOut} \
    --tx-out ${destinationAddress}+${amountToSend} \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
    --fee ${fee} \
    --out-file tx.raw
```

Go back to the host:

```bash
exit
```

**Copy the "tx.raw" file to your air-gapped machine**.

```bash
docker cp cardano-node-1.30.1:/opt/data/tx.raw /<PATH_TO_YOUR_USBSTICK-FOLDER>
```

*If you under Windows and u use WSL you can open folder from Terminal with "explorer.exe ."*

Now sign your transaction with your private key on the air-gapped machine:

```bash
# On air-gapped machine

cardano-cli transaction sign \
    --tx-body-file tx.raw \
    --signing-key-file payment.skey \
    --testnet-magic 1097911063 \
    --out-file tx.signed
```

**Now copy the "tx.signed" file to your hot environment:

```bash
docker cp <PATH_TO_FOLDER>/tx.signed cardano-node-1.30.1:/opt/data
```

Now you can send your signed transaction:

```bash
cardano-cli transaction submit \
    --tx-file tx.signed \
    --testnet-magic 1097911063
    
# Output
Transaction successfully submitted.
```

You can now see if the transaction has arrived:

```bash
cardano-cli query utxo \
    --address addr_test1qzr8qgh6x5ml3y7u52eph2t5m2pumfpxsduz7q26ghe9zap2ucalwdqpj8ylgr6cvyqkttpz0r04flj76u3h694ct76sm8zdgk \
    --testnet-magic 1097911063
  
# Output
                           TxHash                                 TxIx        Amount
--------------------------------------------------------------------------------------
56b44bc7beeec1e8a1adfe7f93ed4e2ded83fc53dd33c30a3f00aba947ff01b2     1        20000000 lovelace + TxOutDatumHashNone
```

Looks good! 

*Remember, whenever you go out of your container, it forgets the variables such as "${destinationAddress}".*

*A big thanks goes also to [CoinCashew](https://www.coincashew.com/coins/overview-ada/guide-how-to-build-a-haskell-stakepool-node#18-9-send-a-simple-transaction-example) for the great contribution. The path of the transaction was created using his tutorial. Feel free to leave him a donation!*