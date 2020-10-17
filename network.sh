# certificate authorities compose file
COMPOSE_FILE_CA=docker/docker-compose-ca.yaml


function caDown() {
  docker-compose -f $COMPOSE_FILE_CA down --volumes --remove-orphans

  ## remove fabric ca artifacts
  rm -rf organizations/fabric-ca/org1/msp organizations/fabric-ca/org1/tls-cert.pem organizations/fabric-ca/org1/ca-cert.pem organizations/fabric-ca/org1/IssuerPublicKey organizations/fabric-ca/org1/IssuerRevocationPublicKey organizations/fabric-ca/org1/fabric-ca-server.db
  rm -rf organizations/fabric-ca/org2/msp organizations/fabric-ca/org2/tls-cert.pem organizations/fabric-ca/org2/ca-cert.pem organizations/fabric-ca/org2/IssuerPublicKey organizations/fabric-ca/org2/IssuerRevocationPublicKey organizations/fabric-ca/org2/fabric-ca-server.db
  rm -rf organizations/fabric-ca/org3/msp organizations/fabric-ca/org3/tls-cert.pem organizations/fabric-ca/org3/ca-cert.pem organizations/fabric-ca/org3/IssuerPublicKey organizations/fabric-ca/org3/IssuerRevocationPublicKey organizations/fabric-ca/org3/fabric-ca-server.db
  rm -rf organizations/fabric-ca/org4/msp organizations/fabric-ca/org4/tls-cert.pem organizations/fabric-ca/org4/ca-cert.pem organizations/fabric-ca/org4/IssuerPublicKey organizations/fabric-ca/org4/IssuerRevocationPublicKey organizations/fabric-ca/org4/fabric-ca-server.db
  rm -rf organizations/fabric-ca/ordererOrg/msp organizations/fabric-ca/ordererOrg/tls-cert.pem organizations/fabric-ca/ordererOrg/ca-cert.pem organizations/fabric-ca/ordererOrg/IssuerPublicKey organizations/fabric-ca/ordererOrg/IssuerRevocationPublicKey organizations/fabric-ca/ordererOrg/fabric-ca-server.db

  echo "===================down ca servers end===================="
}

function caUp() {
  echo "===================start ca servers===================="
  docker-compose -f $COMPOSE_FILE_CA up -d

  docker ps
  echo "===================start ca servers end===================="
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
else
  printHelp
  exit 1
fi