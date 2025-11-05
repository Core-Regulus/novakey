# 🚀 NovaKey

**NovaKey** is a secure key management system designed primarily for **bots**, **AI agents**, and **runtime sandboxes**.  
It uses **ed25519** cryptography to authorize clients.

🔗 **Public API:** [https://novakey-api.core-regulus.com](https://novakey-api.core-regulus.com)

---

## 🧭 Getting Started

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
      - key: # ed25519 public key of the user to grant access #
        roleCode: Project Reader
```

💡 *This file initializes your project configuration. You can modify it later — all updates will be automatically reflected.*  
⚠️ **Never commit `keyPass` to your repository!** All keys are encrypted using this value.

---

### 3. Create a `.novakey-user.yaml` file

This file defines your personal user credentials:

```yaml
email:          # Your email address #
privateKeyFile: # Path to your ed25519 private key #
```

💡 *All operations are performed using this user account.*  
⚠️ **Do not include this file in your repository!**

---

### 4. Use NovaKey in your Go project

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

After the first launch, a **`novakey-launch.yaml`** file will be generated containing:
- Workspace and project IDs  
- API endpoint  
- `keyPass` hash  

You can safely commit this file to your repository.  
Any user who clones the repository and has access to the project will automatically receive all associated project keys.

---

## 📦 Client Libraries

- [Go Client](https://github.com/Core-Regulus/novakey-client)

---

## 📄 License

NovaKey is distributed under the **MIT License**.  
See the [LICENSE](LICENSE) file for more details.

---

## 🧑‍💻 Authors

**Core Regulus Team**  
🌐 [https://core-regulus.com](https://core-regulus.com)
