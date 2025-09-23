package workspaces

import (
	"novakey/internal/requestHandler"
	"github.com/core-regulus/novakey-types-go"
	"github.com/gofiber/fiber/v2"
)

func InitRoutes(app *fiber.App) {	
	app.Post("/workspaces/set", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[novakeytypes.SetWorkspaceRequest, novakeytypes.SetWorkspaceResponse](c, "select workspaces.set_workspace($1::jsonb)")
	})
	app.Post("/workspaces/delete", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[novakeytypes.DeleteWorkspaceRequest, novakeytypes.DeleteWorkspaceResponse](c, "select workspaces.delete_workspace($1::jsonb)")
	})
}
