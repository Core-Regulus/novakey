package requesthandler

import (
	"context"
	"encoding/json"
	"novakey/internal/db"
	"github.com/go-playground/validator/v10"
	"github.com/gofiber/fiber/v2"
	"github.com/core-regulus/novakey-types-go"
)


func validateStruct[T any](key T) error {
	validate := validator.New()
	return validate.Struct(key)
}

func GenericRequestHandler[Request any, Response any](
	c *fiber.Ctx,
	query string,
) error {
	var in Request
	var out Response

	if err := c.BodyParser(&in); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Cannot parse JSON",
		})
	}

	if errs := validateStruct(in); errs != nil {
		validationErrors := []novakeytypes.ValidationErrorResponse{}
		for _, err := range errs.(validator.ValidationErrors) {
			validationErrors = append(validationErrors, novakeytypes.ValidationErrorResponse{
				FailedField: err.Field(),
				Value:       err.Value(),
				Error:       true,
				Tag:         err.Tag(),
			})
		}
		return c.Status(fiber.StatusBadRequest).JSON(validationErrors)
	}

	pool := db.Connect()
	ctx := context.Background()

	inJSON, err := json.Marshal(in)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "cannot marshal request",
		})
	}

	var rawJSON []byte
	err = pool.QueryRow(ctx, query, string(inJSON)).Scan(&rawJSON)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	if err := json.Unmarshal(rawJSON, &out); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "cannot decode db response",
		})
	}

	return c.Status(fiber.StatusOK).JSON(out)
}
