package workspaces

import (
	"github.com/gofiber/fiber/v2"
	"novakey/internal/requestHandler"
	"novakey/internal/users"
	"github.com/google/uuid"
)

type SetProjectRequest struct {
	Id 					uuid.UUID 	`json:"id"`	
	Name 				string 			`json:"name"`
	Description string 			`json:"description"`
}


type SetWorkspaceRequest struct {	
  Id  						string 						`json:"id,omitempty"`
	Name  					string 						`json:"name"`
	User						users.AuthEntity 	`json:"user"`		
	Projects   			[]SetProjectRequest `json:"projects,omitempty"`
}

type SetWorkspaceResponse struct {
	Id 					 			string 	 `json:"id,omitempty"`		
	requesthandler.ErrorResponse
}

type DeleteWorkspaceRequest struct {    
	Id  			string `json:"id"`
	User			users.AuthEntity `json:"user"`
}

type DeleteWorkspaceResponse struct {
	Id  							string 	 `json:"id,omitempty"`
  requesthandler.ErrorResponse
}

func InitRoutes(app *fiber.App) {	
	app.Post("/workspaces/set", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[SetWorkspaceRequest, SetWorkspaceResponse](c, "select workspaces.set_workspace($1::jsonb)")
	})
	app.Post("/workspaces/delete", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[DeleteWorkspaceRequest, DeleteWorkspaceResponse](c, "select workspaces.delete_workspace($1::jsonb)")
	})
}
