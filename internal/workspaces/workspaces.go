package workspaces

import (
	"github.com/gofiber/fiber/v2"
	"novakey/internal/requestHandler"
	"github.com/google/uuid"
)

type SetProjectRequest struct {
	Id 					uuid.UUID 	`json:"id"`	
	Name 				string 			`json:"name"`
	Description string 			`json:"description"`
}


type SetWorkspaceRequest struct {	
  Id  						string `json:"id,omitempty"`
	Email  					string `json:"email"`		  	
	PublicKey    		string `json:"publicKey"`
	Signature 			string `json:"signature"`
  Message   			string `json:"message"`  
  Timestamp 			int64  `json:"timestamp"`  
	Password 				string `json:"password,omitempty"`
	Projects   			[]SetProjectRequest `json:"projects,omitempty"`
}

type SetWorkspaceResponse struct {
	Id								string   `json:"id,omitempty"`			
	Password					string   `json:"password,omitempty"`
	Error     				string 	 `json:"error,omitempty"`
  Code      				string   `json:"code,omitempty"`
	Status						int   	 `json:"status,omitempty"`
	ErrorDescription 	string 	 `json:"errorDescription,omitempty"`
}

type DeleteWorkspaceRequest struct {    
	Id								string `json:"id,omitempty"`		 
	Signature 				string `json:"signature"`
  Message   				string `json:"message"`  
  Timestamp 				int64  `json:"timestamp"`  
	PublicKey    			string `json:"publicKey"`
	Password 					string `json:"password,omitempty"`
}

type DeleteWorkspaceResponse struct {
	Id								string   `json:"id,omitempty"`		
  Code      				string   `json:"code,omitempty"`
	Status						int   	 `json:"status,omitempty"`
	ErrorDescription 	string 	 `json:"errorDescription,omitempty"`
}

func InitRoutes(app *fiber.App) {	
	app.Post("/workspaces/set", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[SetWorkspaceRequest, SetWorkspaceResponse](c, "select workspaces.set_workspace($1::jsonb)")
	})
	app.Post("/workspaces/delete", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[DeleteWorkspaceRequest, DeleteWorkspaceResponse](c, "select workspaces.delete_workspace($1::jsonb)")
	})
}
