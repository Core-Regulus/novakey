package projects

import (
	requesthandler "novakey/internal/requestHandler"
	"novakey/internal/users"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type SetProjectRequest struct {	
  Id  						uuid.UUID 				`json:"id,omitempty"`
	Name  					string 						`json:"name,omitempty"`
	WorkspaceId  		uuid.UUID					`json:"workspaceId,omitempty"`
	Description  		string 						`json:"description,omitempty"`
	User						users.AuthEntity 	`json:"user"`	
}

type SetProjectResponse struct {
	Id 					 		uuid.UUID 	 `json:"id,omitempty"`		
	requesthandler.ErrorResponse
}

type DeleteProjectRequest struct {    
	Id  						uuid.UUID `json:"id"`
	User						users.AuthEntity `json:"user"`
}

type DeleteProjectResponse struct {
	Id  						uuid.UUID 	 `json:"id,omitempty"`
  requesthandler.ErrorResponse
}

func InitRoutes(app *fiber.App) {	
	app.Post("/projects/set", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[SetProjectRequest, SetProjectResponse](c, "select projects.set_project($1::jsonb)")
	})
	app.Post("/projects/delete", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[DeleteProjectRequest, DeleteProjectResponse](c, "select projects.delete_project($1::jsonb)")
	})
}