# Basic Witness Demo

Create a keypair
`openssl genrsa -out buildkey.pem 2048`

Extract the public key
`openssl rsa -in buildkey.pem -outform PEM -pubout -out buildpublic.pem`


Create the policy Template

```yaml
build:
    name: build
    attestations:
      - type: https://witness.dev/attestations/material/v0.1
      - type: https://witness.dev/attestations/product/v0.1
      - type: https://witness.dev/attestations/command-run/v0.1
        regoPolicies:
        - name:  "exitcode"
          module: "{{CMD_MODULE}}"
    functionaries:
      - type: publickey
        publickeyid: "{{KEYID}}"
publickeys:
  "{{KEYID}}":
    keyid: "{{KEYID}}"
    key: "{{KEY}}"
```

Create a rego policy to ensure that the command is rwhat we expect it to be

```rego
package commandrun

deny[msg] {
    input.exitcode != 0
    msg := "exitcode not 0"
}

deny[msg] {
    input.cmd[2] != "echo 'hello' > hello.txt"
    msg := "cmd not correct"
}
```

Use the following script for templating the policy.  It will
1. Generate a key id by taking the sha256 hash of the public key used to sign attestations
2. Base64 encode the PEM encoded public key
3. Base64 encode the rego policy
4. Replace the {{KEYID}} and {{KEY}} placeholders in the template with the generated values
5. Transform the YAML into JSON


```sh
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
```

Create a keypair to sign the policy with

Create a keypair

`openssl genrsa -out policykey.pem 2048`

Extract the public key

`openssl rsa -in policykey.pem -outform PEM -pubout -out policypublic.pem`

Sign the policy

`witness sign -k policykey.pem -f policy.json -o policy.signed.json`


Now we are ready to generate attestations. (hint, make sure hello.txt is not in the current directory)

```sh
witness run -s build -k buildkey.pem -o build-attestation.json -- \
bash -c "echo 'hello' > hello.txt"
```

View the attestation
```sh
cat test-attestation.json | jq -r .payload | base64 -d | jq .
```

Now let's verify the output file `hello.txt` meets our policy.  Notice we use the corresponding public key to validate our policy is trusted.

```sh
witness verify -k policypublic.pem -p policy.signed.json -a \
build-attestation.json -f hello.txt
```

The output should look something like:
```
INFO    Verification succeeded                       
INFO    Evidence:                                    
INFO    0: sha256:a2dccb3ce3b54310cfec2d329493fa62dbc24d3c4c5b961efe7d030704bded42  build-attestation.json
```

Now lets create a second attestation. This time we will create something we expect to fail the policy verification.  Notice we change to product name to `hello.fail.txt`

`witness run -s build -k buildkey.pem -o build-attestation.json -- bash -c "echo 'hello' > hello.fail.txt"`


`witness verify -k policypublic.pem -p policy.signed.json -a build-attestation.json -f hello.fail.txt`


The binary fails our verification since we expect it the output to be `hello.txt`, not `hello.fail.txt` The output should look something like:

```
ERROR   failed to verify policy: failed to verify policy: attestations for step build could not be used due to:
policy was denied due to:
cmd not correct 
```