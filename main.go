package main

import (	
	"novakey/internal/db"	
	"novakey/internal/users"
	"log"
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
	log.Fatal(app.Listen(":5000"))
}
