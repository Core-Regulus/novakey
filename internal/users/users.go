package users

import (
	"novakey/internal/requestHandler"
	"github.com/core-regulus/novakey-types-go"
	"github.com/gofiber/fiber/v2"
)

func InitRoutes(app *fiber.App) {	
	app.Post("/users/set", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[novakeytypes.SetUserRequest, novakeytypes.SetUserResponse](c, "select users.set_user($1::jsonb)")
	})
	app.Post("/users/delete", func(c *fiber.Ctx) error {
    return requesthandler.GenericRequestHandler[novakeytypes.DeleteUserRequest, novakeytypes.DeleteUserResponse](c, "select users.delete_user($1::jsonb)")
	})
}
