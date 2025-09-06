package users

import (
	"context"
	"encoding/json"
	"novakey/internal/db"

	"github.com/go-playground/validator/v10"
	"github.com/gofiber/fiber/v2"
)

type InAuthRequest struct {
    Username  string `json:"email"`
    Project   string `json:"project"`
    Signature string `json:"signature"`
}

type InAddKeyRequest struct {
    Id  string `json:"id,omitempty"`
		Email  string `json:"email,omitempty"`
    Key    string `json:"key,omitempty"`
		Password string `json:"password,omitempty"`
}

type OutKeyResponse struct {
		Id				string   `json:"id,omitempty"`		
		Username	string   `json:"username,omitempty"`
		Password	string   `json:"password,omitempty"`
		Error     string 	 `json:"error,omitempty"`
    Code      string   `json:"code,omitempty"`
		Status		int   	 `json:"status,omitempty"`
}

type ErrorResponse struct {
	Error       bool
	FailedField string
	Value       any
	Tag         string
}

func validateUser(auth InAuthRequest) error {
	validate := validator.New()
	return validate.Struct(auth)
}

func validateKey(key InAddKeyRequest) error {
	validate := validator.New()
	return validate.Struct(key)
}

/*func verifySignature(username string, message, signature []byte) bool {
    pubKeyString, ok := userKeys[username]
    if !ok {
        return false
    }

    pubKey, _, _, _, err := ssh.ParseAuthorizedKey([]byte(pubKeyString))
    if err != nil {
        log.Println("Ошибка парсинга ключа:", err)
        return false
    }

    // Хэшируем сообщение (чтобы длина всегда была одинакова)
    hashed := sha256.Sum256(message)

    err = pubKey.Verify(hashed[:], &ssh.Signature{
        Format: pubKey.Type(),
        Blob:   signature,
    })
    return err == nil
}*/

func postAddKeyHandler(c *fiber.Ctx) error {
	var addKeyReq InAddKeyRequest
	if err := c.BodyParser(&addKeyReq); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Cannot parse JSON",
		})
	}

	if errs := validateKey(addKeyReq); errs != nil {
		validationErrors := []ErrorResponse{}
		for _, err := range errs.(validator.ValidationErrors) {
			validationErrors = append(validationErrors, ErrorResponse{
				FailedField: err.Field(),
				Value:       err.Value(),
				Error:       true,
				Tag:         err.Tag(),
			})
		}
		return c.Status(fiber.StatusBadRequest).JSON(validationErrors)
	}

	pool := db.Connect()
	ctx := context.Background()

	inJSON, err := json.Marshal(addKeyReq)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "cannot marshal request"})
	}

	var rawJSON []byte
	err = pool.QueryRow(ctx, "select users.set_user($1::json)", string(inJSON)).Scan(&rawJSON)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	
	var keyResponse OutKeyResponse
	if err := json.Unmarshal(rawJSON, &keyResponse); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "cannot decode db response"})
	}


	return c.Status(keyResponse.Status).JSON(keyResponse)
}

func postKeysHandler(c *fiber.Ctx) error {
	var authReq InAuthRequest

	if err := c.BodyParser(&authReq); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Cannot parse JSON",
		})
	}

	if errs := validateUser(authReq); errs != nil {
			validationErrors := []ErrorResponse{}
		for _, err := range errs.(validator.ValidationErrors) {
			var elem ErrorResponse
			elem.FailedField = err.Field()
			elem.Value = err.Value()
			elem.Error = true
			elem.Tag = err.Tag()
			validationErrors = append(validationErrors, elem)
		}
		return c.Status(fiber.StatusBadRequest).JSON(validationErrors)
	}

	/*sigBytes, err := base64.StdEncoding.DecodeString(authReq.Signature)
  if err != nil {
    return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Bad signature encoding",
		})
	}*/

  /*if !verifySignature(authReq.Username, []byte(authReq.Project), sigBytes) {
    return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error": "unathorized",  
  	})
	}*/
      	
	/*pool := db.Connect()
	ctx := context.Background()	
	err = pool.QueryRow(ctx, "select users.set_user($1)", authReq).Scan(&user)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err})
	}*/

	
	return c.Status(201).JSON(fiber.Map{"status": "OK", "token": "test"})
}

func InitRoutes(app *fiber.App) {
	app.Post("/users/get", postKeysHandler)
	app.Post("/users/set", postAddKeyHandler)
}
