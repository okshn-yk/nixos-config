{ config, pkgs, ... }:

{
  # AWS Configuration
  # Secrets Difine
  sops.secrets."aws/sso_start_url" = {};
  sops.secrets."aws/account_id/admin" = {};
  sops.secrets."aws/account_id/dev" = {};

  # File Template
  sops.templates."aws-config" = {
    path = "/home/okshin/.aws/config";
    owner = "okshin";
    mode = "0600";
    content = ''
      [sso-session my-sso]
      sso_start_url = ${config.sops.placeholder."aws/sso_start_url"}
      sso_region = us-east-1
      sso_registration_scopes = sso:account:access

      [profile admin]
      sso_session = my-sso
      sso_account_id = ${config.sops.placeholder."aws/account_id/admin"}
      sso_role_name = AdministratorAccess
      region = ap-northeast-1
      output = json

      [profile dev]
      sso_session = my-sso
      sso_account_id = ${config.sops.placeholder."aws/account_id/dev"}
      sso_role_name = DevAdministratorAccess
      region = ap-northeast-1
      output = json
    '';
  };
}
