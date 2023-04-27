variable "instance" {
  type        = string
  description = "Which GuardDuty instance to accept invitations from: `dev` or `prod`. Leave blank to not accept invitations."
}

variable "admin_account" {
  type        = map(string)
  description = "Map of AWS Account IDs for the Security Hub Admin Accounts, keyed on instance."

  default = {
    dev  = "152267171281"
    prod = "636967684097"
  }
}

variable "detectors" {
  type        = map(map(string))
  description = "Map of GuardDuty Detector IDs for the GuardDuty Admin Accounts, keyed on instance and region."

  default = {
    dev = {
      af-south-1     = "e2b579e1f59b4b88a314dc533ffdc1b2"
      ap-east-1      = "266a3e4e8841436b9b7c06d92b8b1690"
      ap-northeast-1 = "7c0250836dcf41928c65951f49ef8f23"
      ap-northeast-2 = "efb7f5f7839f499db7d268a3385cc269"
      ap-northeast-3 = "f96e7db229b748c38479673efea4c28f"
      ap-south-1     = "fe9011c037b544dbb362b9530abc294a"
      ap-southeast-1 = "1fa7c206dbbe4d4c8d5e441f60ddf983"
      ap-southeast-2 = "3b0390b4c14b441e80da383b62c089fd"
      ap-southeast-3 = "dd1a1a2230c34807befaf6ee62afeb9f"
      ca-central-1   = "e255a71718164cf3b54d6ba45d52b9e5"
      eu-central-1   = "0611292bd8904921ac296d7ed5726b69"
      eu-north-1     = "99e1a63a562a42a89f19ed6dd2c22be0"
      eu-south-1     = "caf5542cd16c4652a6ef6b8a16387c73"
      eu-west-1      = "b4bc56df70e3415eb81dcefe808a468d"
      eu-west-2      = "506ad89aeba549ec8e33978d17edfeb9"
      eu-west-3      = "6ba1eb28e03144da99716000e6257cb4"
      me-south-1     = "9e7fdfea57854ed2b2aceedc489532b9"
      sa-east-1      = "b11eca69d79945fa9423edfee37aef78"
      us-east-1      = "b8de3f975fa84b87ab56ec42765e0c4b"
      us-east-2      = "596e126c858d4793adf7e464c57078ad"
      us-west-1      = "6bf051f466574a6c858f67e3a6055b0e"
      us-west-2      = "c452396b47794e3e80ce4585b9ea0766"
    }
    prod = {
      af-south-1     = "c17492d53a9e412f8e5a5e4985fbb6dc"
      ap-east-1      = "6feadcd41db44768ad5fa59a17c00e7e"
      ap-northeast-1 = "0d6ef6a6468c4059a4a9a311e748697d"
      ap-northeast-2 = "ae2217c415954ddcbd30ea2237d6b7b5"
      ap-northeast-3 = "a09fb16e6fb1448a99655ef7b9219eac"
      ap-south-1     = "1823a213971f4eaf979ced9af1096e49"
      ap-southeast-1 = "a5faa81abc1346d08a6fd06386580cf0"
      ap-southeast-2 = "2c3d7b71c7c14768919ad290d40d718d"
      ap-southeast-3 = "b49e5b6a17414d028a70e9d3d612892a"
      ca-central-1   = "35d66bc1a9564172ac3727f1d4be5d36"
      eu-central-1   = "9cecade7354548fb9a9bbbd2c0630188"
      eu-north-1     = "524d9c3302f6442d8565e4e26db8d6ec"
      eu-south-1     = "adcc6c03200142998f8125c60478d0a4"
      eu-west-1      = "2246e04cf3ef4fc388b3308a5f0f0b88"
      eu-west-2      = "5cfc48bc6dd64e8f89fadce59bc12743"
      eu-west-3      = "d26cbc3b6ba04b5cb24c8e4ef7e62dc2"
      me-south-1     = "300aefc6c1b4423bb4a25f2efe3aafb7"
      sa-east-1      = "fb37bd6997844204b9d9f7f3da676583"
      us-east-1      = "804f9a1177bb4c3aa824668796c4dd55"
      us-east-2      = "5165e13fdbc4437e9ff9db9d6c364494"
      us-west-1      = "91b6d3a511114184bca6fb0e224a2572"
      us-west-2      = "704b7d7c0ac2419f9653d88872b49a79"
    }
  }
}
