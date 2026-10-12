# Third-party notices

CastBridge's original code is licensed under Apache-2.0. That choice does
not replace or relicense third-party software. This inventory was checked
against the pinned Python package metadata and license files installed on
the development PC on 2026-10-12.

## Python dependencies

The installer downloads these packages from PyPI into an owned local
environment. The standalone installer payload does not embed their wheels
or the Python interpreter. Upstream notices remain in the installed
packages; copies of the observed license texts are also included under
`third_party/licenses/` for reference and attribution.

- **casttube 0.2.1 — MIT.** `third_party/licenses/casttube-0.2.1/LICENSE`.
- **certifi 2026.7.22 — MPL-2.0.** `third_party/licenses/certifi-2026.7.22/LICENSE`.
- **charset-normalizer 3.5.2 — MIT.** `third_party/licenses/charset-normalizer-3.5.2/LICENSE`.
- **idna 3.20 — BSD-3-Clause.** `third_party/licenses/idna-3.20/LICENSE.md`.
- **ifaddr 0.2.0 — MIT.** `third_party/licenses/ifaddr-0.2.0/LICENSE.txt`.
- **protobuf 7.36.2 — BSD-3-Clause.** `third_party/licenses/protobuf-7.36.2/LICENSE`.
- **PyChromecast 14.0.10 — MIT.** `third_party/licenses/PyChromecast-14.0.10/LICENSE`.
- **requests 2.34.2 — Apache-2.0.** `third_party/licenses/requests-2.34.2/LICENSE` and its upstream `NOTICE`.
- **urllib3 2.8.0 — MIT.** `third_party/licenses/urllib3-2.8.0/LICENSE.txt`.
- **zeroconf 0.151.5 — LGPL-2.1-or-later.** `third_party/licenses/zeroconf-0.151.5/COPYING` preserves upstream historical notices and the LGPL text.

This inventory concerns the packages required by the current lock file.
It is not an audit of every optional extra or vendored subcomponent.
Keep it synchronized with `requirements-prototype.lock.txt` and review
the actual wheels and their contents before changing the distribution.
CastBridge does not modify these upstream packages.

## External runtime and tools

**Python 3.12:** installed separately. Python has its own
[PSF license stack](https://www.python.org/doc/copyright/).
If a future installer embeds Python, preserve the complete license stack,
including applicable notices for bundled standard-library components.

**FFmpeg:** installed separately and invoked as an external executable;
CastBridge does not link its native libraries into the desktop executable.
The development executable reports version 8.1.2, Gyan essentials build,
with `--enable-gpl`, `--enable-version3` and `--enable-libx264`, and reports
GPL version 3 or later. Do not describe that build as LGPL-only.

FFmpeg is not embedded in the current installer. Before bundling it,
review the exact binary, configuration, component licenses and matching
source distribution obligations. A license notice alone is not a complete
redistribution-compliance plan. See
[FFmpeg's legal documentation](https://www.ffmpeg.org/legal.html).
Patent questions are separate from the copyright licenses.

**Virtual Display Driver 25.7.23:** downloaded and prepared separately.
Its upstream source tag contains an
[MIT license](https://github.com/VirtualDrivers/Virtual-Display-Driver/blob/25.7.23/LICENSE),
preserved at `third_party/licenses/VirtualDisplayDriver-25.7.23/LICENSE`.
The current payload contains an original CastBridge helper DLL and a
configuration template, not the vendor driver DLL/CAT/INF package.
Review the exact signed release package and any additional components
before embedding or redistributing it; its code-signing status is distinct
from its copyright license.

**Windows and .NET Framework:** supplied by the operating system and used
under their own applicable terms. The current payload does not redistribute
those runtimes.

## Attribution and release maintenance

Third-party authors retain their rights. Product names are used to identify
dependencies and compatibility, without implying endorsement by their
owners. CastBridge's own name policy is in `TRADEMARKS.md`.

New builds include `LICENSE`, `NOTICE`, this inventory, `TRADEMARKS.md`
and the copied upstream license files. Existing release assets are not
silently replaced; notices for those builds can be read in the repository.
Before embedding external tools or changing dependencies, update the
inventory and verify the applicable redistribution requirements, source
availability, notices and modification/replacement rights.
