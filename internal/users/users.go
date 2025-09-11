package users

import (
	"novakey/internal/requestHandler"
	"github.com/gofiber/fiber/v2"
)

type SetUserRequest struct {	
  Id  						string `json:"id,omitempty"`
	Email  					string `json:"email"`		  	
	PublicKey    		string `json:"publicKey"`
	Signature 			string `json:"signature"`
  Message   			string `json:"message"`  
  Timestamp 			int64  `json:"timestamp"`  
	Password 				string `json:"password,omitempty"`
	ProjectCodes   []string `json:"projectCodes,omitempty"`
}

type SetUserResponse struct {
	Id								string   `json:"id,omitempty"`
	Username					string   `json:"username,omitempty"`
	Password					string   `json:"password,omitempty"`
	Error     				string 	 `json:"error,omitempty"`
  Code      				string   `json:"code,omitempty"`
	Status						int   	 `json:"status,omitempty"`
	ErrorDescription 	string 	 `json:"errorDescription,omitempty"`
}

type DeleteUserRequest struct {
	Id								string `json:"id,omitempty"`		 
	Signature 				string `json:"signature"`
  Message   				string `json:"message"`  
  Timestamp 				int64  `json:"timestamp"`  
	PublicKey    			string `json:"publicKey"`
	Password 					string `json:"password,omitempty"`
}

type DeleteUserResponse struct {
	Id								string   `json:"id,omitempty"`		
  Code      				string   `json:"code,omitempty"`
	Status						int   	 `json:"status,omitempty"`
	Error     				string 	 `json:"error,omitempty"`
	ErrorDescription 	string 	 `json:"errorDescription,omitempty"`
}

func InitRoutes(app *fiber.App) {	
	app.Post("/users/set", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[SetUserRequest, SetUserResponse](c, "select users.set_user($1::jsonb)")
	})
	app.Post("/users/delete", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[DeleteUserRequest, DeleteUserResponse](c, "select users.delete_user($1::jsonb)")
	})
}
