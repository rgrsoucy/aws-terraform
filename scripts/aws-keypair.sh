#!/bin/bash

AWS_PROFILE=${AWS_PROFILE:-coreos-cluster}
CLUSTER_NAME=${CLUSTER_NAME:-coreos-cluster}
AWS_ACCOUNT=${AWS_ACCOUNT:-}
AWS_REGION=${AWS_REGION:-us-west-2}

# Default keypair name
key="${CLUSTER_NAME}-default"

if [ "X${AWS_ACCOUNT}" = "X" ];
then
  echo "Getting AWS account number..."
  AWS_ACCOUNT=$(aws --profile ${AWS_PROFILE} iam get-user | jq ".User.Arn" | grep -Eo '[[:digit:]]{12}')
fi

TMP_DIR=keypairs

create(){
  if  aws --profile ${AWS_PROFILE} --region ${AWS_REGION} ec2 describe-key-pairs --key-name ${key} > /dev/null 2>&1 ;
  then
    echo "keypair ${key} already exists."
  else
    mkdir -p ${TMP_DIR}
    chmod 700 ${TMP_DIR}
    echo "Creating keypair ${key}"
    aws --profile ${AWS_PROFILE} --region ${AWS_REGION} ec2 create-key-pair --key-name ${key} --query 'KeyMaterial' --output text > ${TMP_DIR}/${key}.pem
    # copy the key to user's home .ssh
    # cp ${TMP_DIR}/${key}.pem ${HOME}/.ssh; chmod 600 ${HOME}/.ssh/${key}.pem
    chmod 600 ${TMP_DIR}/${key}.pem
    echo "ssh-add ${TMP_DIR}/${key}.pem"
    ssh-add ${TMP_DIR}/${key}.pem
    # Clean up
    # rm -rf ${TMP_DIR}
  fi
}

exist(){
  if aws --profile ${AWS_PROFILE} --region ${AWS_REGION} ec2 describe-key-pairs --key-name ${key} > /dev/null 2>&1 ;
  then
    return 0
  else
    return 1
  fi
}
destroy(){
  if  ! aws --profile ${AWS_PROFILE} --region ${AWS_REGION} ec2 describe-key-pairs --key-name ${key} > /dev/null 2>&1 ;
  then
    echo "keypair ${key} does not exists."
  else
    if [ -f ${TMP_DIR}/${key}.pem ];
    then
      echo "Remove from ssh agent"
      ssh-add -L |grep "${TMP_DIR}/${key}.pem" > ${TMP_DIR}/${key}.pub
      [ -s ${TMP_DIR}/${key}.pub ] && ssh-add -d ${TMP_DIR}/${key}.pub
      rm -rf ${TMP_DIR}/${key}.pem
      rm -rf ${TMP_DIR}/${key}.pub
    fi
    aws --profile ${AWS_PROFILE} --region ${AWS_REGION}  s3 rm s3://${AWS_ACCOUNT}-${CLUSTER_NAME}-config/keypairs/${key}.pem
    echo "Delete aws keypair ${key}"
    aws --profile ${AWS_PROFILE} --region ${AWS_REGION} ec2 delete-key-pair --key-name ${key}  
    echo "Remove from ${TMP_DIR}"
  fi 
}

while getopts ":c:d:e:h" OPTION
do
  key=$OPTARG
  case $OPTION in
    c)
      create
      ;;
    d)
      destroy
      ;;
    e)
      exist
      ;;
    *)
      echo "Usage: $(basename $0) -c|-d|-e keyname"
      exit 1
      ;;
  esac
done
