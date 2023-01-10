# Generating and Verifying Attestations With Witness

### Generating a KeyPair
The first step is to generate a keypair that will be used to sign the attestations. This can be done with the following OpenSSL command:

`openssl genrsa -out buildkey.pem 2048`

Next, we will extract the public key from the keypair:

`openssl rsa -in buildkey.pem -outform PEM -pubout -out buildpublic.pem`

### Generating the Attestations
Now that we have created the keypairs, we can you use to sign attestations we generate.

Important Note: Witness generates the product attestation based on new files in the working directory. Make sure hello.txt does NOT exist when running this command.

```
#rm hello.txt
witness run -s build -k buildkey.pem -o build-attestation.json -- \
bash -c "echo 'hello' > hello.txt"
```

This command will generate the attestations for the build step, using the private key that we generated earlier. The generated attestations will be saved to the build-attestation.json file.

### Viewing the Attestation
To view the contents of the attestation, you can use the following command:

`cat build-attestation.json | jq -r .payload | base64 -d | jq .`
This will print the contents of the attestation in a human-readable format.

### Specifying the Rego Constraints
One of the key features of Witness is its ability to enforce policies using the Open Policy Agent (OPA) rego language. This allows us to specify rules that must be followed when generating attestations, and ensures that the artifacts produced by the pipeline meet the requirements specified in the policy.

To create the rego policy, we first need to define the rules that we want to enforce. For example, if we want to ensure that the hello.txt file is created with the correct contents, we could use the following rego policy:

```
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

This policy specifies two rules:

The command must exit with a return code of 0.
The command must be the correct command for creating the hello.txt file.
But these are just examples - the rego policy can be based on any attribute in the attestation. For example, we could create a policy that checks the user who ran the command, the environment variables used, or the current working directory. This allows us to create highly customizable and granular policies to ensure the integrity and security of our build process.

Creating the Witness Policy
The next step is to create the policy that will be used to verify the attestations. This policy template is written in YAML and specifies the types of attestations that will be generated, as well as the rules that the attestations must follow.

Here is an example policy template:

```
cat <<EOF >> policy-template.yaml
expires: "2035-12-17T23:57:40-05:00"
steps:
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
    key:
EOF
```

In this policy, we specify that the build step will generate three types of attestations: material, product, and command-run. We also specify a rego policy named exitcode that will be used to verify the exit code of the command that is run. Finally, we specify that the public key that we generated earlier will be used to sign the attestations.

It is important to note that the policy template can be used to define multiple steps in a CI pipeline, and each step can have its own set of attestations and rules. This allows us to create complex and granular policies that ensure the integrity of our build process from start to finish.

### Templating the Policy
Before we can use the policy, we need to template it by replacing the placeholders with the actual values. This can be done with the following script:

```
cat <<EOF >> template-policy.sh
#requires yq v4.2.0
cmd_b64="$(openssl base64 -A <"cmd.rego")"
pubkey_b64="$(openssl base64 -A <"buildpublic.pem")"
cp policy-template.yaml policy.tmp.yaml
keyid=`sha256sum buildpublic.pem | awk '{print $1}'`
sed -i "s/{{KEYID}}/$keyid/g" policy.tmp.yaml
yq eval ".publickeys.${keyid}.key = \"${pubkey_b64}\"" --inplace policy.tmp.yaml
sed -i "s/{{CMD_MODULE}}/$cmd_b64/g" policy.tmp.yaml
yq e -j policy.tmp.yaml > policy.json
EOF
sh ./template-policy.sh
```

This script generates a key id by taking the sha256 hash of the public key used to sign attestations, base64 encodes the PEM encoded public key and the rego policy, and replaces the {{KEYID}} and {{CMD_MODULE}} placeholders in the policy template with the generated values. It then transforms the YAML policy into JSON.

### Signing the Witness Policy

Signing the policy is an important step in the attestation process, as it ensures the authenticity and integrity of the policy. This is essential for ensuring the security of the build process and preventing tampering of build materials and artifacts.

In order to sign the policy, we need to use a keypair that is trusted by the verification process. This keypair can be generated using OpenSSL.

To generate the keypair that will be used to sign the policy, we can use the openssl genrsa command, as shown below:

`openssl genrsa -out policykey.pem 2048`
Next, we will extract the public key from the keypair, we will need this later:

`openssl rsa -in policykey.pem -outform PEM -pubout -out policypublic.pem`
Once the keypair has been generated, we can use the private key to sign the policy using the Witness sign command, as described in the previous section. The corresponding public key can then be used to verify the signed policy and the attestations you generated.

Now you can then sign the policy using the witness sign command, which takes the JSON policy file as input and produces a signed policy file as output.

`witness sign -k policykey.pem -f policy.json -o policy.signed.json`
The signed policy file is then used to verify the attestations generated by the CI pipeline. This ensures that the policy has not been tampered with and that it can be trusted by the verification process.

### Verifying the Attestations
Once the policy has been signed and the attestations have been generated, we can use the witness verify command to verify that the attestations meet the requirements specified in the policy. This is done by running the witness verify command with the following arguments:

witness verify -k policypublic.pem -p policy.signed.json -a build-attestation.json -f hello.txt
The -k argument specifies the public key that was used to sign the policy, and the -p argument specifies the signed policy file. The -a argument specifies the attestation file that was generated by the CI pipeline, and the -f argument specifies the artifact that was produced by the pipeline.

If the attestations meet the requirements specified in the policy, the witness verify command will output a message indicating that the verification succeeded along with references to the evidence. If the attestations do not meet the requirements, the witness verify command will output an error message indicating which requirement was not met

One of the key benefits of using Witness is that it is not only a standalone tool, but also a library that can be embedded into other applications such as admission controllers and runtime visibili
