# certificate authorities compose file
COMPOSE_FILE_CA=docker/docker-compose-ca.yaml
# Using crpto vs CA. default is cryptogen
CRYPTO="Certificate Authorities"
# use this as the default docker-compose yaml definition
COMPOSE_FILE_BASE=docker/docker-compose-test-net.yaml
# docker-compose.yaml file if you are using couchdb
COMPOSE_FILE_COUCH=docker/docker-compose-couch.yaml
CHANNEL_NAME="mychannel"
DATABASE="couchdb"
# timeout duration - the duration the CLI should wait for a response from
# another container before giving up
MAX_RETRY=5
# default for delay between commands
CLI_DELAY=3

export FABRIC_CFG_PATH=${PWD}/configtx


function caDown() {
  docker-compose -f $COMPOSE_FILE_CA down --volumes --remove-orphans

  ## remove fabric ca artifacts
  rm -rf organizations/fabric-ca/org1/msp organizations/fabric-ca/org1/tls-cert.pem organizations/fabric-ca/org1/ca-cert.pem organizations/fabric-ca/org1/IssuerPublicKey organizations/fabric-ca/org1/IssuerRevocationPublicKey organizations/fabric-ca/org1/fabric-ca-server.db
  rm -rf organizations/fabric-ca/org2/msp organizations/fabric-ca/org2/tls-cert.pem organizations/fabric-ca/org2/ca-cert.pem organizations/fabric-ca/org2/IssuerPublicKey organizations/fabric-ca/org2/IssuerRevocationPublicKey organizations/fabric-ca/org2/fabric-ca-server.db
  rm -rf organizations/fabric-ca/org3/msp organizations/fabric-ca/org3/tls-cert.pem organizations/fabric-ca/org3/ca-cert.pem organizations/fabric-ca/org3/IssuerPublicKey organizations/fabric-ca/org3/IssuerRevocationPublicKey organizations/fabric-ca/org3/fabric-ca-server.db
  rm -rf organizations/fabric-ca/org4/msp organizations/fabric-ca/org4/tls-cert.pem organizations/fabric-ca/org4/ca-cert.pem organizations/fabric-ca/org4/IssuerPublicKey organizations/fabric-ca/org4/IssuerRevocationPublicKey organizations/fabric-ca/org4/fabric-ca-server.db
  rm -rf organizations/fabric-ca/ordererOrg/msp organizations/fabric-ca/ordererOrg/tls-cert.pem organizations/fabric-ca/ordererOrg/ca-cert.pem organizations/fabric-ca/ordererOrg/IssuerPublicKey organizations/fabric-ca/ordererOrg/IssuerRevocationPublicKey organizations/fabric-ca/ordererOrg/fabric-ca-server.db
  rm -rf organizations/peerOrganizations
  rm -rf organizations/ordererOrganizations
  echo "===================down ca servers end===================="
}

function caUp() {
  echo "===================start ca servers===================="
  docker-compose -f $COMPOSE_FILE_CA up -d

  docker ps
  echo "===================start ca servers end===================="
}

# Create Organziation crypto material using cryptogen or CAs
function createOrgs() {

  if [ -d "organizations/peerOrganizations" ]; then
    rm -Rf organizations/peerOrganizations && rm -Rf organizations/ordererOrganizations
  fi

  # Create crypto material using cryptogen
  if [ "$CRYPTO" == "cryptogen" ]; then
    which cryptogen
    if [ "$?" -ne 0 ]; then
      echo "cryptogen tool not found. exiting"
      exit 1
    fi
    echo
    echo "##########################################################"
    echo "##### Generate certificates using cryptogen tool #########"
    echo "##########################################################"
    echo

    echo "##########################################################"
    echo "############ Create Org1 Identities ######################"
    echo "##########################################################"

    set -x
    cryptogen generate --config=./organizations/cryptogen/crypto-config-org1.yaml --output="organizations"
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate certificates..."
      exit 1
    fi

    echo "##########################################################"
    echo "############ Create Org2 Identities ######################"
    echo "##########################################################"

    set -x
    cryptogen generate --config=./organizations/cryptogen/crypto-config-org2.yaml --output="organizations"
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate certificates..."
      exit 1
    fi

    echo "##########################################################"
    echo "############ Create Orderer Org Identities ###############"
    echo "##########################################################"

    set -x
    cryptogen generate --config=./organizations/cryptogen/crypto-config-orderer.yaml --output="organizations"
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate certificates..."
      exit 1
    fi

  fi

  # Create crypto material using Fabric CAs
  if [ "$CRYPTO" == "Certificate Authorities" ]; then

    fabric-ca-client version > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "Fabric CA client not found locally, downloading..."
      cd ..
      curl -s -L "https://github.com/hyperledger/fabric-ca/releases/download/v1.4.4/hyperledger-fabric-ca-${OS_ARCH}-1.4.4.tar.gz" | tar xz || rc=$?
    if [ -n "$rc" ]; then
        echo "==> There was an error downloading the binary file."
        echo "fabric-ca-client binary is not available to download"
    else
        echo "==> Done."
      cd test-network
    fi
    fi

    echo
    echo "##########################################################"
    echo "##### Generate certificates using Fabric CA's ############"
    echo "##########################################################"

    caUp

    . organizations/fabric-ca/registerEnroll.sh

    sleep 10

    echo "##########################################################"
    echo "############ Create Org1 Identities ######################"
    echo "##########################################################"

    createOrg1

    echo "##########################################################"
    echo "############ Create Org2 Identities ######################"
    echo "##########################################################"

    createOrg2

    echo "##########################################################"
    echo "############ Create Org3 Identities ######################"
    echo "##########################################################"

    createOrg3

    echo "##########################################################"
    echo "############ Create Org4 Identities ######################"
    echo "##########################################################"

    createOrg4

    echo "##########################################################"
    echo "############ Create Orderer Org Identities ###############"
    echo "##########################################################"

    createOrderer

  fi

  echo
  echo "Generate CCP files for Org1 and Org2"
#  ./organizations/ccp-generate.sh

  chmod -R 777 organizations/
}

function createConsortium() {
  echo "#########  Generating Orderer Genesis block ##############"

  set -x
  configtxgen -profile FourOrgsOrdererGenesis -channelID system-channel -outputBlock ./system-genesis-block/genesis.block
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate orderer genesis block..."
    exit 1
  fi
}

function networkUp() {
  caUp
  createOrgs
  createConsortium

  COMPOSE_FILES="-f ${COMPOSE_FILE_BASE}"

  if [ "${DATABASE}" == "couchdb" ]; then
    COMPOSE_FILES="${COMPOSE_FILES} -f ${COMPOSE_FILE_COUCH}"
  fi
  docker-compose ${COMPOSE_FILES} up -d

  docker ps -a
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to start network"
    exit 1
  fi
}

function createChannel() {

## Bring up the network if it is not arleady up.

  if [ ! -d "organizations/peerOrganizations" ]; then
    echo "Bringing up network"
    networkUp
  fi

  # now run the script that creates a channel. This script uses configtxgen once
  # more to create the channel creation transaction and the anchor peer updates.
  # configtx.yaml is mounted in the cli container, which allows us to use it to
  # create the channel artifacts
 scripts/createChannel.sh $CHANNEL_NAME $CLI_DELAY $MAX_RETRY $VERBOSE
  if [ $? -ne 0 ]; then
    echo "Error !!! Create channel failed"
    exit 1
  fi

}

function networkDown() {
    caDown
    docker-compose -f $COMPOSE_FILE_BASE -f $COMPOSE_FILE_COUCH down --volumes --remove-orphans
    rm -rf system-genesis-block/*.block

    # remove channel and script artifacts
    rm -rf channel-artifacts log.txt fabcar.tar.gz fabcar
}


if [[ $# -lt 1 ]] ; then
  printHelp
  exit 0
else
  MODE=$1
  shift
fi

if [ "${MODE}" == "caUp" ]; then
  caUp
elif [ "${MODE}" == "caDown" ]; then
  caDown
elif [ "${MODE}" == "createOrgs" ]; then
  createOrgs
elif [ "${MODE}" == "up" ]; then
  networkUp
elif [ "${MODE}" == "down" ]; then
  networkDown
else
  printHelp
  exit 1
fi