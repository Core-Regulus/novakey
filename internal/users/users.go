package users

import (
	"novakey/internal/requestHandler"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type AuthEntity struct {
	Id 				uuid.UUID `json:"id,omitempty"`
	PublicKey string 		`json:"publicKey"`
	Signature string 		`json:"signature"`
	Message   string 		`json:"message"`  
	Timestamp int64  		`json:"timestamp"`  
	Password 	string 		`json:"password,omitempty"`
}

type Workspace struct {
	Id 				uuid.UUID `json:"id"`
	RoleCode  string 		`json:"roleCode"`
}

type SetUserRequest struct {	
	AuthEntity
	Email						string   `json:"email,omitempty"`
	Workspaces   		[]Workspace `json:"workspaces,omitempty"`
	Signer					AuthEntity `json:"signer"`
}

type SetUserResponse struct {	
	Id								uuid.UUID   `json:"id,omitempty"`	
	Username					string  		`json:"username,omitempty"`
	Password					string   		`json:"password,omitempty"`
	requesthandler.ErrorResponse
}

type DeleteUserRequest struct {
	AuthEntity
}

type DeleteUserResponse struct {
	Id								uuid.UUID   `json:"id,omitempty"`		
  requesthandler.ErrorResponse
}

func InitRoutes(app *fiber.App) {	
	app.Post("/users/set", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[SetUserRequest, SetUserResponse](c, "select users.set_user($1::jsonb)")
	})
	app.Post("/users/delete", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[DeleteUserRequest, DeleteUserResponse](c, "select users.delete_user($1::jsonb)")
	})
}
