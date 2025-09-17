package workspaces

import (
	"novakey/internal/requestHandler"
	"novakey/internal/users"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)


type SetWorkspaceRequest struct {	
  Id  						uuid.UUID 				`json:"id,omitempty"`
	Name  					string 						`json:"name"`
	User						users.AuthEntity 	`json:"user"`	
}

type SetWorkspaceResponse struct {
	Id 					 		uuid.UUID 	 `json:"id,omitempty"`		
	requesthandler.ErrorResponse
}

type DeleteWorkspaceRequest struct {    
	Id  						uuid.UUID `json:"id"`
	User						users.AuthEntity `json:"user"`
}

type DeleteWorkspaceResponse struct {
	Id  						uuid.UUID 	 `json:"id,omitempty"`
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
