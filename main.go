package main

import (
	"log"
	"novakey/internal/db"
	"novakey/internal/projects"
	"novakey/internal/users"
	"novakey/internal/workspaces"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
)

func main() {
	app := fiber.New()
	app.Use(cors.New(cors.Config{
		AllowOrigins: "https://novakey.core-regulus.com, http://localhost:9001",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
		AllowMethods: "POST, OPTIONS",
	}))
	db.Connect()	
	users.InitRoutes(app)
	workspaces.InitRoutes(app)
	projects.InitRoutes(app)
	log.Fatal(app.Listen(":5000"))
}
