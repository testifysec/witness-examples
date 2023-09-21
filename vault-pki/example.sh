#!/usr/bin/env bash

# Clean up files from previous runs
rm ./policy-signed.json ./test.txt ./test.json ./testkey.pem ./testpub.pem

export VAULT_ADDR="https://your-vault-instance:8200";
export VAULT_PKI_PATH="example-pki"
export VAULT_NAMESPACE="admin"
export VAULT_ROLE_ID="your-vault-role-id"
export VAULT_ROLE_NAME="my-first-vault-cert"
export VAULT_ROLE_SECRET_ID="your-vault-role-secret-id"
export VAULT_PKI_ISSUER="default"

export VAULT_TOKEN=$(curl -s --header "X-Vault-Namespace: $VAULT_NAMESPACE" \
    --request POST --data '{"role_id": "'"$VAULT_ROLE_ID"'", "secret_id": "'"$VAULT_ROLE_SECRET_ID"'"}' \
     $VAULT_ADDR/v1/auth/approle/login | jq -r '.auth.client_token' )

# Get the root CA for the Vault issuer
export VAULT_ROOT=$(curl -s -H "X-Vault-Namespace: $VAULT_NAMESPACE" \
 -H "X-Vault-Token: $VAULT_TOKEN" \
 "$VAULT_ADDR/v1/$VAULT_PKI_PATH/issuer/$VAULT_PKI_ISSUER/json"\
 | jq -r '.data.certificate' | base64)

# Create the witness policy
cat <<EOF > policy.json
{
  "expires": "2030-12-17T23:57:40-05:00",
  "steps": {
    "test": {
      "name": "test",
      "attestations": [
        {
          "type": "https://witness.dev/attestations/product/v0.1"
        }
      ],
      "functionaries": [
        {
          "type": "root",
          "certConstraint": {
            "commonname": "hcp-magic.example.com",
            "dnsnames": ["*"],
            "emails": ["*"],
            "organizations": ["*"],
            "uris": ["*"],
            "roots": [
              "vault-pki"
            ]
          }
        }
      ]
    }
  },
  "roots": {
    "vault-pki": {
      "certificate": "$VAULT_ROOT",
      "intermediates": []
    }
  },
  "timestampauthorities": {
    "freetsa": {
      "certificate": "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUgvekNDQmVlZ0F3SUJBZ0lKQU1IcGhoWU5xT21BTUEwR0NTcUdTSWIzRFFFQkRRVUFNSUdWTVJFd0R3WUQKVlFRS0V3aEdjbVZsSUZSVFFURVFNQTRHQTFVRUN4TUhVbTl2ZENCRFFURVlNQllHQTFVRUF4TVBkM2QzTG1aeQpaV1YwYzJFdWIzSm5NU0l3SUFZSktvWklodmNOQVFrQkZoTmlkWE5wYkdWNllYTkFaMjFoYVd3dVkyOXRNUkl3CkVBWURWUVFIRXdsWGRXVnllbUoxY21jeER6QU5CZ05WQkFnVEJrSmhlV1Z5YmpFTE1Ba0dBMVVFQmhNQ1JFVXcKSGhjTk1UWXdNekV6TURFMU1qRXpXaGNOTkRFd016QTNNREUxTWpFeldqQ0JsVEVSTUE4R0ExVUVDaE1JUm5KbApaU0JVVTBFeEVEQU9CZ05WQkFzVEIxSnZiM1FnUTBFeEdEQVdCZ05WQkFNVEQzZDNkeTVtY21WbGRITmhMbTl5Clp6RWlNQ0FHQ1NxR1NJYjNEUUVKQVJZVFluVnphV3hsZW1GelFHZHRZV2xzTG1OdmJURVNNQkFHQTFVRUJ4TUoKVjNWbGNucGlkWEpuTVE4d0RRWURWUVFJRXdaQ1lYbGxjbTR4Q3pBSkJnTlZCQVlUQWtSRk1JSUNJakFOQmdrcQpoa2lHOXcwQkFRRUZBQU9DQWc4QU1JSUNDZ0tDQWdFQXRnS09EakF5OFJFUTJXVE5xVXVkQW5qaGxDcnBFNnFsCm1RZk5wcGVUbVZ2WnJINHp1dG4rTndUYUhBR3BqU0d2NC9XUnBaMXdaM0JSWjVtUFVCWnlMZ3EwWXJJZlE1RngKMHMvTVJaUHpjMXIzbEtXck1SOXNBUXg0bU40ejExeEZFTzUyOUwwZEZKalBGOU1EOEdwZDJmZVd6R3lwdGxlbApiK1BxVCsrK2ZPYTJvWTArTmFNTTdsL3hjTkhQT2FNejAvMm9sazBpMjJoYktlVmh2b2tQQ3FoRmh6c3VoS3NtCnE0T2Yvbyt0NmRJN3N4NWgwblBNbTRnR1NSaGZxK3o2QlRSZ0NycVFHMkZPTG9WRmd0NmlJbS9Cbk5mZlVyN1YKRFlkM3pabUl3Rk9qL0gzREtIb0dpay94SzNFODJZQTJadWxWT0ZSVy96ajRBcGpQYTVPRmJwSWtkMHBtenh6ZApFY0w0NzloU0E5ZEZpeVZtU3hQdFk1emUxUCtCRTliTVUxUFNjcFJ6dzhNSEZYeHlLcVcxM1F2N0xXdzRzYmszClNjaUI3R0FDYlFpVkd6Z2t2WEc2eTg1SE91dldOdkM1R0xTaXlQOUdsUEIwVjY4dGJ4ejRKVlRSZHcvWG4vWFQKRk56UkJNM2NxOGxCT0FWdC9QQVg1K3VGY3YxUzl3RkU4WWphQmZXQ1AxamRCaWwrYzRlKzB0ZHl3VDJvSm1ZQgpCRi9rRXQxd21Hd01tSHVuTkV1UU56aDFGdEpZNTRoYlVmaVdpMzhtQVNFN3hNdE1oZmovQzRTdmFwaUROODM3CmdZYVBmczh4M0taeGJYN0MzWUFzRm5KaW5sd0FVc3MxZmRLYXI4US9ZVnM3SC9uVTRjNEl4eHh6NGY2N2ZjVnEKTTJJVEtlbnRiQ01DQXdFQUFhT0NBazR3Z2dKS01Bd0dBMVVkRXdRRk1BTUJBZjh3RGdZRFZSMFBBUUgvQkFRRApBZ0hHTUIwR0ExVWREZ1FXQkJUNlZRMk1OR1pSUTB6MzU3T25iSld2ZXVha2x6Q0J5Z1lEVlIwakJJSENNSUcvCmdCVDZWUTJNTkdaUlEwejM1N09uYkpXdmV1YWtsNkdCbTZTQm1EQ0JsVEVSTUE4R0ExVUVDaE1JUm5KbFpTQlUKVTBFeEVEQU9CZ05WQkFzVEIxSnZiM1FnUTBFeEdEQVdCZ05WQkFNVEQzZDNkeTVtY21WbGRITmhMbTl5WnpFaQpNQ0FHQ1NxR1NJYjNEUUVKQVJZVFluVnphV3hsZW1GelFHZHRZV2xzTG1OdmJURVNNQkFHQTFVRUJ4TUpWM1ZsCmNucGlkWEpuTVE4d0RRWURWUVFJRXdaQ1lYbGxjbTR4Q3pBSkJnTlZCQVlUQWtSRmdna0F3ZW1HRmcybzZZQXcKTXdZRFZSMGZCQ3d3S2pBb29DYWdKSVlpYUhSMGNEb3ZMM2QzZHk1bWNtVmxkSE5oTG05eVp5OXliMjkwWDJOaApMbU55YkRDQnp3WURWUjBnQklISE1JSEVNSUhCQmdvckJnRUVBWUh5SkFFQk1JR3lNRE1HQ0NzR0FRVUZCd0lCCkZpZG9kSFJ3T2k4dmQzZDNMbVp5WldWMGMyRXViM0puTDJaeVpXVjBjMkZmWTNCekxtaDBiV3d3TWdZSUt3WUIKQlFVSEFnRVdKbWgwZEhBNkx5OTNkM2N1Wm5KbFpYUnpZUzV2Y21jdlpuSmxaWFJ6WVY5amNITXVjR1JtTUVjRwpDQ3NHQVFVRkJ3SUNNRHNhT1VaeVpXVlVVMEVnZEhKMWMzUmxaQ0IwYVcxbGMzUmhiWEJwYm1jZ1UyOW1kSGRoCmNtVWdZWE1nWVNCVFpYSjJhV05sSUNoVFlXRlRLVEEzQmdnckJnRUZCUWNCQVFRck1Da3dKd1lJS3dZQkJRVUgKTUFHR0cyaDBkSEE2THk5M2QzY3VabkpsWlhSellTNXZjbWM2TWpVMk1EQU5CZ2txaGtpRzl3MEJBUTBGQUFPQwpBZ0VBYUs5K3Y1T0ZZdTlNNnp0WUMrTDY5c3cxb21keWxpODlsWkFmcFdNTWg5Q1JtSmhNNktCcU0vaXB3b0x0Cm54eXhHc2JDUGhjUWp1VHZ6bSt5bE42VndUTW1JbFZ5VlNMS1laY2RTanQvZUNVTis0MUs3c0Q3R1ZteFpCQUYKSUxuQkRtVEdKbUxrclUwS3V1SXBqOGxJL0U2WjZObm11UDIrUkFRU0hzZkJRaTZzc3NuWE1vNEhPVzVndFBPNwpnRHJVcFZYSUQrKzFQNFhuZGtvS243U3Z3NW4welM5ZnYxaHhCY1lJSFBQUVV6ZTJ1MzBiQVF0MG4waUl5Ukx6CmFXdWh0cEF0ZDdmZndFYkFTZ3pCN0UrTkdGNHRwVjM3ZThLaUEyeGlHU1JxVDVuZHUyOGZncE9ZODdnRDNBcloKRGN0WnZ2VENmSGRBUzVrRU8zZ25HR2VaRVZMRG1mRXN2OFRHSmEzQWxqVmE1RTQwSVFEc1VYcFFMaThHK1VDNAoxRFdadThFVlQ0cm5ZYUN3MVZYN1NoT1IxUE5DQ3ZqYjhTOHRmZHVkZDl6aFUzZ0VCMHJ4ZGVUeTF0VmJOTFhXCjk5eTkweGN3cjFaSURVd00veFEvbm9POEZSaG0wTG9QQzczRWYrSjRaQmRydld3YXVGM3pKZTMzZDRpYnhFY2IKOC9wejVXekZrZWl4WU0ybnNIaHFIc0JLdzdKUG91S05YUm5sNUlBRTFlRm1xRHlDN0cvVlQ3T0Y2Njl4TTZoYgpVdDVHMjFKRTRjTks2Tk51Y1MrZnpnMUpQWDArM1Zoc1laamo3RDV1bGpSdlFYcko4aUhnci9NNmoyb0xIdlRBCkkyTUxkcTJxalpGRE9DWHN4QnhKcGJtTEdCeDlvdzZaZXJsVXh6d3MyQVd2MnBrPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0t"
    }
  }
}
EOF

# Sign the witness policy
openssl genpkey -algorithm ed25519 -outform PEM -out testkey.pem
openssl pkey -in testkey.pem -pubout > testpub.pem
witness sign -k testkey.pem -o policy-signed.json -f policy.json

# Create an attestation signed by vault
witness run -s test -o test.json  --signer-vault-url="$VAULT_ADDR" \
    --signer-vault-pki-secrets-engine-path="$VAULT_PKI_PATH" \
    --signer-vault-token="$VAULT_TOKEN" \
    --signer-vault-commonname="hcp-magic.example.com" \
    --signer-vault-role="$VAULT_ROLE_NAME" \
    --signer-vault-namespace="$VAULT_NAMESPACE" \
    --timestamp-servers="https://freetsa.org/tsr" \
    -- echo "hello" > test.txt

# Verify that our attestation satisifes our policy
witness verify -p policy-signed.json -a test.json -k testpub.pem -f test.txt -l debug