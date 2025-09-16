package users

import (
	"novakey/internal/requestHandler"
	"github.com/gofiber/fiber/v2"
)

type AuthEntity struct {
	Id 				string `json:"id,omitempty"`
	PublicKey string `json:"publicKey"`
	Signature string `json:"signature"`
	Message   string `json:"message"`  
	Timestamp int64  `json:"timestamp"`  
	Password 	string `json:"password,omitempty"`
}

type SetUserRequest struct {	
	AuthEntity
	Email							string   `json:"email,omitempty"`
	ProjectCodes   []string `json:"projectCodes,omitempty"`
}

type SetUserResponse struct {	
	Id								string   `json:"id,omitempty"`	
	Username					string   `json:"username,omitempty"`
	Password					string   `json:"password,omitempty"`
	requesthandler.ErrorResponse
}

type DeleteUserRequest struct {
	AuthEntity
}

type DeleteUserResponse struct {
	Id								string   `json:"id,omitempty"`		
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
