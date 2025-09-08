package users

import (
	"context"
	"encoding/json"
	"novakey/internal/db"

	"github.com/go-playground/validator/v10"
	"github.com/gofiber/fiber/v2"
)


type SignedRequest struct {  
  
}


type AddUserRequest struct {	
  Id  					string `json:"id,omitempty"`
	Email  				string `json:"email"`		  	
	PublicKey    	string `json:"publicKey"`
	Signature string `json:"signature"`
  Message   string `json:"message"`  
  Timestamp int64  `json:"timestamp"`  
	Password 			string `json:"password,omitempty"`
}

type AddUserResponse struct {
	Id								string   `json:"id,omitempty"`		
	Username					string   `json:"username,omitempty"`
	Password					string   `json:"password,omitempty"`
	Error     				string 	 `json:"error,omitempty"`
  Code      				string   `json:"code,omitempty"`
	Status						int   	 `json:"status,omitempty"`
	ErrorDescription 	string 	 `json:"errorDescription,omitempty"`
}

type DeleteUserRequest struct {    
	Signature string `json:"signature"`
  Message   string `json:"message"`  
  Timestamp int64  `json:"timestamp"`  
	PublicKey    	string `json:"publicKey"`
	Password 			string `json:"password,omitempty"`
}

type DeleteUserResponse struct {
	Id								string   `json:"id,omitempty"`		
  Code      				string   `json:"code,omitempty"`
	Status						int   	 `json:"status,omitempty"`
	ErrorDescription 	string 	 `json:"errorDescription,omitempty"`
}

type ErrorResponse struct {
	Error       bool
	FailedField string
	Value       any
	Tag         string
}
func validateStruct[T any](key T) error {
    validate := validator.New()
    return validate.Struct(key)
}

func genericRequestHandler[Request any, Response any](
    c *fiber.Ctx,
    query string,
) error {
    var in Request
    var out Response

    if err := c.BodyParser(&in); err != nil {
        return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
            "error": "Cannot parse JSON",
        })
    }

    if errs := validateStruct(in); errs != nil {        
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

    inJSON, err := json.Marshal(in)
    if err != nil {
        return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
            "error": "cannot marshal request",
        })
    }

    var rawJSON []byte
    err = pool.QueryRow(ctx, query, string(inJSON)).Scan(&rawJSON)
    if err != nil {
        return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
            "error": err.Error(),
        })
    }

    if err := json.Unmarshal(rawJSON, &out); err != nil {
        return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
            "error": "cannot decode db response",
        })
    }

    return c.Status(fiber.StatusOK).JSON(out)
}

func InitRoutes(app *fiber.App) {	
	app.Post("/users/set", func(c *fiber.Ctx) error {
    return genericRequestHandler[AddUserRequest, AddUserResponse](c, "select users.set_user($1::jsonb)")
	})
	app.Post("/users/delete", func(c *fiber.Ctx) error {
    return genericRequestHandler[AddUserRequest, AddUserResponse](c, "select users.delete_user($1::jsonb)")
	})
}
