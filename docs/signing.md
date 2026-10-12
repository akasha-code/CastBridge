# Code signing policy

CastBridge previews are currently unsigned. No certificate, Azure subscription or paid signing account has been provisioned for this project.

## SignPath Foundation evaluation — 12 October 2026

SignPath Foundation offers free signing for eligible open-source projects. CastBridge appears to meet several baseline conditions: Apache-2.0 project licensing, documented third-party open-source licenses, active maintenance, released binaries, documented behavior and uninstall support. This is a preliminary assessment, not approval or a guarantee of acceptance. See the [official conditions](https://signpath.org/terms.html).

The Foundation certificate identifies SignPath Foundation as the signing publisher. CastBridge's product name and MateKraft attribution remain in the application. We must not claim that SignPath provides this project with signing before acceptance.

Before applying:

- Establish a verifiable automated Windows build from repository source. Current releases were built locally; there is no GitHub Actions build workflow yet. Pin the native toolchain and retain the build's provenance.
- Add and verify product-name and version metadata on the project-owned native helper DLL. Executables currently contain product metadata, but the GCC-built helper lacks a version resource.
- Confirm MFA for all signing and repository maintainers. The authenticated GitHub API did not return the account's MFA status, so it remains unverified.
- Record signing roles. Proposed maintainer, reviewer and signing approver: repository owner [akasha-code](https://github.com/akasha-code). Reviews of outside contributions and manual release-signing approval are required.
- Review third-party packaging boundaries with SignPath. The project-owned executable and helper are signing candidates; upstream binaries must not be re-signed as our own code. The external driver keeps its existing signatures.
- Demonstrate project reputation and provide the repository, download page and build description. A new public project may need more history before acceptance.

No application has been submitted. [Apply](https://signpath.org/apply) after these gaps are addressed. The Foundation makes the final eligibility decision.

## Privacy and system changes

CastBridge transmits the selected virtual desktop to a receiver explicitly selected by the user. It uses local-network discovery and local HTTP delivery. Installation downloads dependencies from PyPI; optional website and support links open only when selected. No telemetry service is implemented. Display content can contain personal information chosen by the user, and local transport is not encrypted. See [validation and boundaries](validation.md) and [installation](../INSTALL.md).

System-wide driver configuration changes require an explanation, confirmation and Windows administrator permission. Existing XML is backed up. Uninstall removes owned application files while retaining preferences and logs; external prerequisites remain separate.

## Paid publisher signing alternative

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
