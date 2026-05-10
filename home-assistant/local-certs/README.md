# Trusting The Local HTTPS CA

This directory contains the public root CA certificate used for local HTTPS on:

- `smart.casa`
- `smart.home.arpa`
- `hass.casa`
- `hass.home.arpa`
- `guard.casa`
- `guard.home.arpa`
- `portainer.casa`
- `portainer.home.arpa`
- `matter.casa`
- `matter.home.arpa`

The certificate file to install on client devices is:

- `casa-rootCA.pem`

This is the public CA certificate only. The CA private key is not stored in this workspace.

## Why this is needed

The reverse proxy uses a certificate signed by a private local CA created with `mkcert`.

Browsers and apps will trust `https://smart.casa` and the other local names only if this CA is installed in the client trust store.

## Device trust steps

Use the copy of the CA that lives in this directory:

- `casa-rootCA.pem`

If a platform or import wizard prefers `.crt`, make a copy named `casa-rootCA.crt` and import that copy.

### Windows 10 and 11

GUI method:

1. Copy `casa-rootCA.pem` to the Windows machine.
2. If the import wizard complains about `.pem`, rename a copy to `casa-rootCA.crt`.
3. Double-click the certificate file.
4. Choose `Install Certificate`.
5. Select `Local Machine` if you want all users and apps to trust it. Select `Current User` if you only want trust for your own profile.
6. Choose `Place all certificates in the following store`.
7. Select `Trusted Root Certification Authorities`.
8. Finish the wizard and accept the trust warning.

Command-line method:

For the current user:

```powershell
certutil -user -addstore Root casa-rootCA.pem
```

For all users, in an elevated shell:

```powershell
certutil -addstore Root casa-rootCA.pem
```

### macOS

GUI method:

1. Open `Keychain Access`.
2. Import `casa-rootCA.pem` into the `System` keychain if you want all users to trust it. The `login` keychain is enough for a single user.
3. Double-click the imported certificate.
4. Expand `Trust`.
5. Set `When using this certificate` to `Always Trust`.

Command-line method:

```sh
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain casa-rootCA.pem
```

### iPhone and iPad

1. Transfer `casa-rootCA.pem` to the device by AirDrop, Mail, Files, or a local web share.
2. Open the file and accept the profile install prompt.
3. Go to `Settings > General > VPN & Device Management` and complete the profile installation if prompted.
4. Then go to `Settings > General > About > Certificate Trust Settings`.
5. Enable full trust for the installed root certificate.

Without the final trust toggle, Safari will still warn even though the profile is installed.

### Android

1. Copy `casa-rootCA.pem` to the device.
2. If the import UI prefers `.crt`, rename a copy to `casa-rootCA.crt`.
3. Open `Settings` and search for `Install certificate`, `Encryption & credentials`, or `Security certificates`.
4. Import the certificate as a `CA certificate`.
5. Accept the warning about network monitoring.

Notes:

- Browsers usually trust user-installed CAs.
- Some Android apps ignore user-installed CAs and only trust the system CA store.
- If an app still warns after the CA is installed, test in the browser first to separate app behavior from certificate-install problems.

### Linux

Linux trust depends on the distribution and, sometimes, on the browser.

Debian and Ubuntu:

```sh
sudo cp casa-rootCA.pem /usr/local/share/ca-certificates/casa-rootCA.crt
sudo update-ca-certificates
```

Fedora, RHEL, Rocky, AlmaLinux, and CentOS Stream:

```sh
sudo cp casa-rootCA.pem /etc/pki/ca-trust/source/anchors/casa-rootCA.crt
sudo update-ca-trust extract
```

Arch and Manjaro:

```sh
sudo trust anchor casa-rootCA.pem
sudo trust extract-compat
```

openSUSE:

```sh
sudo cp casa-rootCA.pem /etc/pki/trust/anchors/casa-rootCA.crt
sudo update-ca-certificates
```

If you only need a one-off CLI test and do not want to install the CA system-wide:

```sh
curl --cacert casa-rootCA.pem https://smart.casa
```

### Firefox

Firefox may use its own trust store, especially on Linux.

GUI method:

1. Open `Settings`.
2. Go to `Privacy & Security`.
3. Scroll to `Certificates`.
4. Open `View Certificates`.
5. Go to `Authorities`.
6. Import `casa-rootCA.pem`.
7. Trust it for identifying websites.

If Firefox is already configured to trust the OS certificate store, the manual Firefox import may not be necessary.

### ChromeOS

ChromeOS support varies by version and device policy.

If certificate import is allowed:

1. Open `Settings`.
2. Search for `Manage certificates`.
3. Open the `Authorities` tab.
4. Import `casa-rootCA.pem`.
5. Trust it for websites.

If the device is managed and CA import is blocked, use the browser on another trusted device or handle trust through the device-management policy instead.

### Other clients

For headless tools, containers, and scripts, the quickest option is usually to point the client directly at the CA file instead of importing it system-wide.

Examples:

```sh
curl --cacert casa-rootCA.pem https://smart.casa
wget --ca-certificate=casa-rootCA.pem https://smart.casa
```

## Verifying trust

After installing the CA on a device that uses AdGuard for DNS, these URLs should open without certificate warnings:

- `https://smart.casa`
- `https://smart.home.arpa`
- `https://hass.casa`
- `https://hass.home.arpa`
- `https://guard.casa`
- `https://guard.home.arpa`
- `https://portainer.casa`
- `https://portainer.home.arpa`
- `https://matter.casa`
- `https://matter.home.arpa`

You can also verify the certificate chain directly with:

```sh
openssl s_client -connect smart.casa:443 -servername smart.casa -CAfile casa-rootCA.pem </dev/null
```

## Common issues

- If the name does not resolve at all, the device is probably not using AdGuard Home as DNS.
- If the name resolves but the browser still warns, the CA is not installed or not fully trusted on that device.
- On iPhone and iPad, the trust toggle under `Certificate Trust Settings` is easy to miss.
- On Android, some apps ignore user-installed CAs even when the browser works.
- On Linux, Firefox may need its own import even after the system trust store is updated.

## Maintenance and adding more names

The service-routing maintenance runbook lives in [local-service-names.md](/root/docker/home-assistant/local-service-names.md).

If a client has trouble with the `.casa` names, prefer the matching `.home.arpa` alias because `.home.arpa` is reserved for local home-network use.

In short, adding a new local name usually means:

1. Add a DNS rewrite in [AdGuardHome.yaml](/root/docker/adguard-home/conf/AdGuardHome.yaml).
2. Add or extend a matching HTTPS server block in `/root/docker/nginx-proxy-manager/data/nginx/custom/http.conf`.
3. Regenerate the SAN certificate with the full hostname list, not just the new hostname.
4. Reload nginx and restart AdGuard Home.
5. Install or reuse this same root CA on any client that should trust the new HTTPS name.

## Safe retirement later

If you stop using local HTTPS:

1. Remove the TLS host routing from nginx.
2. Remove the local DNS rewrites if they are no longer wanted.
3. Uninstall the CA from client devices.
4. Optionally delete `casa-rootCA.pem` from this directory.