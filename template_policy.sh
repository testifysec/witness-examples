#/bin/sh
#requires yq v4.2.0
cmd_b64="$(openssl base64 -A <"cmd.rego")"
pubkey_b64="$(openssl base64 -A <"buildpublic.pem")"
cp policy-template.yaml policy.tmp.yaml
keyid=`sha256sum buildpublic.pem | awk '{print $1}'`
sed -i "s/{{KEYID}}/$keyid/g" policy.tmp.yaml
yq eval ".publickeys.${keyid}.key = \"${pubkey_b64}\"" --inplace policy.tmp.yaml
sed -i "s/{{CMD_MODULE}}/$cmd_b64/g" policy.tmp.yaml
yq e -j policy.tmp.yaml > policy.json

