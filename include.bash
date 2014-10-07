#
# Please edit the following lines to configure how this cluster
#   will be configured
#
#   AZURE_PubFile points to your Azure .publishsettings file
#     allowing the script to operate under your account.
#   AZURE_VMName to be the root name for resources that will
#     be created to build the cluster.  AZURE_VMName must be
#     between 3-24 chars long
#   AZURE_Location defines the region the cluster will be
#     created in.  For efficiency, it should be geographically
#     close to you
#   AZURE_User is the initial login user name for the machines
#     in the cluster.
#   AZURE_PASS is the initial password associated with
#     AZURE_User
#   AZURE_Template defines the Azure virtual machine image that
#     will be used to construct your OS environment
#   AZURE_VMSize is the machine size to instantiate as nodes
#     in the cluster.  All nodes are the same size.
#   AZURE_DiskCount is the number of additional disks to
#     attach to each node in the cluster.  Each disk is
#     configured as 1TB.
#   AZURE_SlaveCount is the number of worker nodes to bring
#     up in the cluster
#

AZURE_PubFile="EDITHERE"
# 3-24 chars
AZURE_VMName="EDITHERE"
AZURE_Location="West US"
AZURE_Template="b39f27a8b8c64d52b05eac6a62ebad85__Ubuntu-12_04_5-LTS-amd64-server-20140909.2-en-us-30GB"
#AZURE_Template="5112500ae3b842c8b9c604889f8753c3__OpenLogic-CentOS-65-20140910"
AZURE_User="azureuser"
AZURE_Pass="User@123"
AZURE_SlaveCount=2
AZURE_VMSize="a5"
AZURE_SAName="$AZURE_VMName""sa"
AZURE_VNet="$AZURE_VMName""VNet"
AZURE_SubNet="Subnet-1"
AZURE_DiskCount=0
AZURE_MasterScript="sge-master-install.bash"
AZURE_MasterConfScript="sge-master-conf.bash"
AZURE_SlaveScript="sge-slave.bash"
AZURE_SGEQConf="sge-queue.conf"
AZURE_SGEHostgroup="sge-hostgroup.conf" # auto genterated
