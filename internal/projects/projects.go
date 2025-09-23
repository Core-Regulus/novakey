package projects

import (
	requesthandler "novakey/internal/requestHandler"	
	"github.com/core-regulus/novakey-types-go"
	"github.com/gofiber/fiber/v2"	
)

func InitRoutes(app *fiber.App) {	
	app.Post("/projects/set", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[novakeytypes.SetProjectRequest, novakeytypes.SetProjectResponse](c, "select projects.set_project($1::jsonb)")
	})
	app.Post("/projects/delete", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[novakeytypes.DeleteProjectRequest, novakeytypes.DeleteProjectResponse](c, "select projects.delete_project($1::jsonb)")
	})
}