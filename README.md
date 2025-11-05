# 🚀 NovaKey

**NovaKey** is a key management system designed primarily for **bots**, **AI agents**, and **runtime sandboxes**.  
It uses **ed25519** cryptography for client authorization.

🔗 **Public API:** [https://novakey-api.core-regulus.com](https://novakey-api.core-regulus.com)

---

## 🧭 How to Use

### 1. Generate an ed25519 key pair

NovaKey requires a public/private ed25519 key pair for authentication and project access.

---

### 2. Create a `.novakey-init.yaml` file

Example configuration:

```yaml
backend:
  endpoint: https://novakey-api.core-regulus.com

workspace:
  name: # Your workspace name #
  description: # Description of your workspace #

  project:
    name: # Your project name #
    keyPass: # Password used to encrypt project keys #
    description: # Description of your project #
    keys:
      - name: # Key name 1 #
        value: # Key value 1 #
      - name: # Key name 2 #
        value: # Key value 2 #
    users:
      - key: # ed25519 public key of a user you want to grant access to #
        roleCode: Project Reader
```

💡 *This file initializes your project configuration. You can modify it later, and changes will be reflected automatically.*  
⚠️ **Do not include `keyPass` in your repository!** All keys are encrypted using this value.

---

### 3. Create a `.novakey-user.yaml` file

This file defines your user credentials:

```yaml
email:          # Your email address #
privateKeyFile: # Path to your ed25519 private key #
```

💡 *All operations are executed using this user account.*  
⚠️ **Do not include this file in your repository!**

---

### 4. Use the NovaKey Client in your Go code

📦 Install the client library:

```bash
go get github.com/core-regulus/novakey-client
```

📄 Example usage:

```go
package main

import (
    "log"
    novakeyclient "github.com/core-regulus/novakey-client"
)

func main() {
    launchCfg, err := novakeyclient.NewClient(novakeyclient.InitConfig{Directory: "."})
    if err != nil {
        log.Fatalf("Config error: %v", err)
    }

    log.Printf("Using key: %s", launchCfg)
}
```

After the first launch, a **`novakey-launch.yaml`** file will be created containing:
- Workspace and project IDs  
- API endpoint  
- `keyPass` hash  

You can safely store this file in your repository.  
Any user who clones the repo and has project access will automatically receive all project keys.

---

## 🧩 Features

- 🔐 Secure key encryption and storage  
- 👥 User-based access management  
- ☁️ Centralized API  
- 🧰 Simple Go integration

---

## 📄 License

NovaKey is distributed under the **MIT License**.  
See the [LICENSE](LICENSE) file for details.

---

## 🧑‍💻 Author

**Core Regulus Team**  
🌐 [https://core-regulus.com](https://core-regulus.com)
