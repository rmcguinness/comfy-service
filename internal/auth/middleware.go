package auth

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"google.golang.org/api/oauth2/v2" // Use Google's library for validation
	"google.golang.org/api/option"
)

// AuthMiddleware creates a Gin middleware for Google OAuth token validation.
func AuthMiddleware(googleClientID string, allowedDomain string) gin.HandlerFunc {
	// Initialize Google OAuth2 service (can be done once)
	oauth2Service, err := oauth2.NewService(context.Background(), option.WithoutAuthentication()) // No auth needed to call tokeninfo
	if err != nil {
		log.Fatalf("Failed to create OAuth2 service: %v", err)
	}

	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Authorization header format must be Bearer {token}"})
			return
		}
		token := parts[1]

		// Validate the token using Google's tokeninfo endpoint
		tokenInfoCall := oauth2Service.Tokeninfo()
		tokenInfoCall.AccessToken(token) // Send token for validation
		tokenInfo, err := tokenInfoCall.Do()

		if err != nil {
			log.Printf("Token validation error: %v", err)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid token", "details": err.Error()})
			return
		}

		// **IMPORTANT SECURITY CHECK:** Validate the audience claim matches your Client ID.
		// This ensures the token was intended for your application.
		if tokenInfo.Audience != googleClientID {
			log.Printf("Token audience mismatch. Expected: %s, Got: %s", googleClientID, tokenInfo.Audience)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid token audience"})
			return
		}

		// Check if token is expired (Google's API might already do this, but good practice)
		if tokenInfo.ExpiresIn <= 0 {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Token expired"})
			return
		}

		// Optional: Check for allowed domain
		if allowedDomain != "" {
			// The 'hd' claim contains the G Suite domain, if present
			if tokenInfo.Hd != allowedDomain {
				log.Printf("Domain mismatch. Expected: %s, Got: %s (Email: %s)", allowedDomain, tokenInfo.Hd, tokenInfo.Email)
				c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": fmt.Sprintf("Access restricted to domain %s", allowedDomain)})
				return
			}
		}

		// Store user info in context if needed by handlers
		c.Set("userID", tokenInfo.UserId)
		c.Set("userEmail", tokenInfo.Email)

		c.Next() // Token is valid, proceed to the handler
	}
}