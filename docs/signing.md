# Publisher signing

CastBridge previews are currently unsigned. No certificate, Azure subscription or paid signing account has been provisioned for this project.

Microsoft recommends [Azure Artifact Signing](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options) for Windows applications distributed outside the Store. Its Public Trust service is available to organizations in Norway. MateKraft AS must complete organization identity validation using its legal business name, business identifier, website and domain email addresses. An Azure subscription and Microsoft Entra tenant are required. See the [setup guide](https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart) and [pricing](https://azure.microsoft.com/en-us/pricing/details/artifact-signing/).

## Release order

1. Build and test the desktop executable and project-owned native helper.
2. Sign those files using the validated publisher profile and timestamping.
3. Package the signed files and compile the installer around that payload.
4. Sign and timestamp the final installer.
5. Verify the signature and trust chain of every distributed executable, including installed files. Calculate SHA-256 checksums after signing and upload the verified artifacts.

Signing changes file hashes. It must happen before the final checksums and upload. Never commit credentials or private signing keys. Use narrowly scoped signing access when automating builds.

A trusted signature identifies the verified publisher and protects file integrity. It does not guarantee an immediate absence of SmartScreen warnings: reputation develops across releases. See [SmartScreen guidance](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation). A self-signed certificate does not provide public publisher trust and must not be used to ask users to alter Windows trust settings.

The external display driver keeps its upstream signatures; CastBridge does not re-sign it.

[MateKraft — matekraft.tech](https://matekraft.tech) · [Buy me a coffee](https://www.buymeacoffee.com/matekraft)
