## Using Witness with a public/private keypair

### Download the Binary
[Releases](https://github.com/testifysec/witness/releases)
```
curl -LO https://github.com/testifysec/witness/releases/download/${VERSION}/witness_${VERSION}_${ARCH}.tar.gz
tar -xzf witness_${VERSION}_${ARCH}.tar.gz
```

### Create a Keypair

> Witness supports keyless signing with [SPIRE](https://spiffe.io/)!

```
openssl genpkey -algorithm ed25519 -outform PEM -out testkey.pem
openssl pkey -in testkey.pem -pubout > testpub.pem
```

### Create a Witness configuration

> - This file generally resides in your source code repository along with the public keys generated above.
> - `.witness yaml` is the default location for the configuration file
> - `witness help` will show all configuration options
> - command-line arguments overrides configuration file values.

```
## .witness.yaml

run:
    key: testkey.pem
    trace: false
verify:
    attestations:
        - "test-att.json"
    policy: policy-signed.json
    publickey: testpub.pem
```

### Record attestations for a build step

> - The `-a {attestor}` flag allows you to define which attestors run
> - ex. `-a maven -a was -a gitlab` would be used for a maven build running on a GitLab runner on GCP.
> - Defining step names is important, these will be used in the policy.
> - This should happen as a part of a CI step

```
witness run --step build -o test-att.json -- go build -o=testapp .
```

### View the attestation data in the signed DSSE Envelope

> - This data can be stored and retrieved from rekor!
> - This is the data that is evaluated against the Rego policy

```
cat test-att.json | jq -r .payload | base64 -d | jq
```

### Create a Policy File

Look [here](docs/policy.md) for full documentation on Witness Policies.

> - Make sure to replace the keys in this file with the ones from the step above (sed command below).
> - Rego policies should be base64 encoded
> - Steps are bound to keys. Policy can be written to check the certificate data. For example, we can require a step is signed by a key with a specific `CN` attribute.
> - Witness will require all attestations to succeed
> - Witness will evaluate the rego policy against the JSON object in the corresponding attestor

```
## policy.json

{
  "expires": "2023-12-17T23:57:40-05:00",
  "steps": {
    "build": {
      "name": "build",
      "attestations": [
        {
          "type": "https://witness.dev/attestations/material/v0.1",
          "regopolicies": []
        },
        {
          "type": "https://witness.dev/attestations/command-run/v0.1",
          "regopolicies": []
        },
        {
          "type": "https://witness.dev/attestations/product/v0.1",
          "regopolicies": []
        }
      ],
      "functionaries": [
        {
          "publickeyid": "{{PUBLIC_KEY_ID}}"
        }
      ]
    }
  },
  "publickeys": {
    "{{PUBLIC_KEY_ID}}": {
      "keyid": "{{PUBLIC_KEY_ID}}",
      "key": "{{B64_PUBLIC_KEY}}"
    }
  }
}
```

### Replace the variables in the policy

```
id=`sha256sum testpub.pem | awk '{print $1}'` && sed -i "s/{{PUBLIC_KEY_ID}}/$id/g" policy.json
pubb64=`cat testpub.pem | base64 -w 0` && sed -i "s/{{B64_PUBLIC_KEY}}/$pubb64/g" policy.json
```

### Sign The Policy File

Keep this key safe, its owner will control the policy gates.

```
witness sign -f policy.json --key testkey.pem --outfile policy-signed.json
```

### Verify the Binary Meets Policy Requirements

> This process works across air-gap as long as you have the signed policy file, correct binary, and public key or certificate authority corresponding to the private key that signed the policy.
> `witness verify` will return a `non-zero` exit and reason in the case of failure. Success will be silent with a `0` exit status
> for policies that require multiple steps, multiple attestations are required.

```
witness verify -f testapp -a test-att.json -p policy-signed.json -k testpub.pem
```

