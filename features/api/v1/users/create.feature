@api/v1
Feature: Create user

  Background:
    Given the following "accounts" exist:
      | Name    | Slug  |
      | Test 1  | test1 |
      | Test 2  | test2 |
    And I send and accept JSON

  Scenario: Endpoint should be inaccessible when account is disabled
    Given the account "test1" is canceled
    Given I am an admin of account "test1"
    And the current account is "test1"
    And I use an authentication token
    When I send a POST request to "/accounts/test1/users"
    Then the response status should be "403"

  Scenario: Anonymous creates a user for an account (without role)
    Given the current account is "test1"
    And the current account has 1 "webhook-endpoint"
    And the first "webhook-endpoint" has the following attributes:
      """
      {
        "subscriptions": ["user.created", "user.updated"]
      }
      """
    And the current account has 1 "user"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Clark",
            "lastName": "Kent",
            "email": "superman@keygen.sh",
            "password": "kent <3 lois"
          }
        }
      }
      """
    Then the response status should be "201"
    And the JSON response should be a "user" with the firstName "Clark"
    And the JSON response should be a "user" with the role "user"
    And the response should contain a valid signature header for "test1"
    And the current account should have 2 "users"
    And sidekiq should have 1 "webhook" job
    And sidekiq should have 1 "metric" job
    And sidekiq should have 1 "request-log" job

  Scenario: Anonymous creates a user for an account (with role)
    Given the current account is "test1"
    And the current account has 1 "webhook-endpoint"
    And the first "webhook-endpoint" has the following attributes:
      """
      {
        "subscriptions": ["user.created", "user.updated"]
      }
      """
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Clark",
            "lastName": "Kent",
            "email": "superman@keygen.sh",
            "password": "loislane",
            "role": "user"
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Bad request",
        "detail": "Unpermitted parameters: /data/attributes/role"
      }
      """
    And the response should contain a valid signature header for "test1"
    And the current account should have 0 "users"
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: Anonymous creates a user with a short password
    Given the current account is "test1"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "email": "invalid@keygen.example",
            "password": "short"
          }
        }
      }
      """
    Then the response status should be "422"
    And the first error should have the following properties:
      """
      {
          "title": "Unprocessable resource",
          "detail": "is too short (minimum is 6 characters)",
          "source": {
            "pointer": "/data/attributes/password"
          },
          "code": "PASSWORD_TOO_SHORT"
        }
      """

  Scenario: Anonymous creates a user with no name
    Given the current account is "test1"
    And the current account has 1 "webhook-endpoint"
    And the first "webhook-endpoint" has the following attributes:
      """
      {
        "subscriptions": ["user.created", "user.updated"]
      }
      """
    And the current account has 1 "user"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "email": "cap@keygen.sh",
            "password": "america!"
          }
        }
      }
      """
    Then the response status should be "201"
    And the JSON response should be a "user" with a nil firstName
    And the JSON response should be a "user" with a nil lastName
    And the JSON response should be a "user" with the role "user"
    And the response should contain a valid signature header for "test1"
    And the current account should have 2 "users"
    And sidekiq should have 1 "webhook" job
    And sidekiq should have 1 "metric" job
    And sidekiq should have 1 "request-log" job

  Scenario: Anonymous attempts to create a user for a protected account
    Given the current account is "test1"
    And the account "test1" has the following attributes:
      """
      { "protected": true }
      """
    And the current account has 1 "webhook-endpoint"
    And the current account has 1 "user"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Clark",
            "lastName": "Kent",
            "email": "superman@keygen.sh",
            "password": "superman+lois"
          }
        }
      }
      """
    Then the response status should be "403"
    And the JSON response should be an array of 1 error
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: Anonymous attempts to create an incomplete user for an account
    Given the current account is "test1"
    And the current account has 1 "user"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Clark",
            "lastName": "Kent",
            "email": "superman@keygen.sh"
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error

  Scenario: Anonymous attempts to create a user with invalid parameter types
    Given the current account is "test1"
    And the current account has 1 "user"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Clark",
            "lastName": "Kent",
            "email": 42,
            "password": "superman+lois"
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error

  Scenario: Anonymous attempts to create a user with an invalid email
    Given the current account is "test1"
    And the current account has 1 "user"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Clark",
            "lastName": "Kent",
            "email": "foo.com",
            "password": "superman <3 lois"
          }
        }
      }
      """
    Then the response status should be "422"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Unprocessable resource",
        "detail": "must be a valid email",
        "code": "EMAIL_INVALID",
        "source": {
          "pointer": "/data/attributes/email"
        }
      }
      """

  Scenario: Admin creates a user for their protected account
    Given I am an admin of account "test1"
    And the current account is "test1"
    And the account "test1" has the following attributes:
      """
      { "protected": true }
      """
    And the current account has 2 "webhook-endpoints"
    And the first "webhook-endpoint" has the following attributes:
      """
      {
        "subscriptions": []
      }
      """
    And I use an authentication token
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Tony",
            "lastName": "Stark",
            "email": "ironman@keygen.sh",
            "password": "!jarvis!"
          }
        }
      }
      """
    Then the response status should be "201"
    And the JSON response should be a "user" with the role "user"
    And sidekiq should have 1 "webhook" job
    And sidekiq should have 1 "metric" job
    And sidekiq should have 1 "request-log" job

  Scenario: Developer creates a user for their protected account
    Given the current account is "test1"
    And the account "test1" has the following attributes:
      """
      { "protected": true }
      """
    And the current account has 1 "developer"
    And I am a developer of account "test1"
    And I use an authentication token
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Tony",
            "lastName": "Stark",
            "email": "ironman@keygen.sh",
            "password": "!jarvis!"
          }
        }
      }
      """
    Then the response status should be "201"

  Scenario: Sales creates a user for their protected account
    Given the current account is "test1"
    And the account "test1" has the following attributes:
      """
      { "protected": true }
      """
    And the current account has 1 "sales-agent"
    And I am a sales agent of account "test1"
    And I use an authentication token
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Tony",
            "lastName": "Stark",
            "email": "ironman@keygen.sh",
            "password": "((jarvis))"
          }
        }
      }
      """
    Then the response status should be "403"

  Scenario: Support creates a user for their account
    Given the current account is "test1"
    And the account "test1" has the following attributes:
      """
      { "protected": true }
      """
    And the current account has 1 "support-agent"
    And I am a support agent of account "test1"
    And I use an authentication token
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Tony",
            "lastName": "Stark",
            "email": "ironman@keygen.sh",
            "password": "secret123"
          }
        }
      }
      """
    Then the response status should be "403"

  Scenario: Admin creates an admin for their account
    Given I am an admin of account "test1"
    And the current account is "test1"
    And I use an authentication token
    And the current account has 3 "webhook-endpoints"
    And all "webhook-endpoints" have the following attributes:
      """
      {
        "subscriptions": ["user.created"]
      }
      """
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "email": "ironman@keygen.sh",
            "password": "secret123",
            "role": "admin"
          }
        }
      }
      """
    Then the response status should be "201"
    And the JSON response should be a "user" with the role "admin"
    And sidekiq should have 3 "webhook" jobs
    And sidekiq should have 1 "metric" job
    And sidekiq should have 1 "request-log" job

  Scenario: Admin creates a developer for their account
    Given I am an admin of account "test1"
    And the current account is "test1"
    And I use an authentication token
    And the current account has 1 "webhook-endpoint"
    And all "webhook-endpoints" have the following attributes:
      """
      {
        "subscriptions": ["user.created"]
      }
      """
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Mr.",
            "lastName": "Robot",
            "email": "mr.robot@keygen.sh",
            "password": "l337h4x0r",
            "role": "developer"
          }
        }
      }
      """
    Then the response status should be "201"
    And the JSON response should be a "user" with the role "developer"
    And sidekiq should have 1 "webhook" job
    And sidekiq should have 1 "metric" job
    And sidekiq should have 1 "request-log" job

  Scenario: Admin creates a sales agent for their account
    Given I am an admin of account "test1"
    And the current account is "test1"
    And I use an authentication token
    And the current account has 1 "webhook-endpoint"
    And all "webhook-endpoints" have the following attributes:
      """
      {
        "subscriptions": ["user.created"]
      }
      """
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Jim",
            "lastName": "Halpert",
            "email": "jim@keygen.sh",
            "password": "bears beets battlestar galactica",
            "role": "sales-agent"
          }
        }
      }
      """
    Then the response status should be "201"
    And the JSON response should be a "user" with the role "sales-agent"
    And sidekiq should have 1 "webhook" job
    And sidekiq should have 1 "metric" job
    And sidekiq should have 1 "request-log" job

  Scenario: Admin creates a support agent for their account
    Given I am an admin of account "test1"
    And the current account is "test1"
    And I use an authentication token
    And the current account has 1 "webhook-endpoint"
    And all "webhook-endpoints" have the following attributes:
      """
      {
        "subscriptions": ["user.created"]
      }
      """
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Pam",
            "lastName": "Beesly",
            "email": "beesly@keygen.sh",
            "password": "jimjimjimjim",
            "role": "support-agent"
          }
        }
      }
      """
    Then the response status should be "201"
    And the JSON response should be a "user" with the role "support-agent"
    And sidekiq should have 1 "webhook" job
    And sidekiq should have 1 "metric" job
    And sidekiq should have 1 "request-log" job

  Scenario: Developer attempts to create an admin for their account
    Given the current account is "test1"
    And the current account has 1 "developer"
    And I am a developer of account "test1"
    And I use an authentication token
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Mr.",
            "lastName": "Robot",
            "email": "ecorp@keygen.sh",
            "password": "password",
            "role": "admin"
          }
        }
      }
      """
    Then the response status should be "400"

  Scenario: Admin attempts to create a user with an invalid role
    Given I am an admin of account "test1"
    And the current account is "test1"
    And I use an authentication token
    And the current account has 3 "webhook-endpoints"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Spiderman",
            "lastName": "Parker",
            "email": "spiderman@keygen.sh",
            "password": "i shoot webs",
            "role": "spider"
          }
        }
      }
      """
    Then the response status should be "400"
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: Product creates an admin for their account
    Given the current account is "test1"
    And the current account has 1 "product"
    And I am a product of account "test1"
    And I use an authentication token
    And the current account has 1 "webhook-endpoint"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Ironman",
            "lastName": "Stark",
            "email": "ironman@keygen.sh",
            "password": "my suit's cool",
            "role": "admin"
          }
        }
      }
      """
    Then the response status should be "400"
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: Product creates a user for a protected account
    Given the current account is "test1"
    And the account "test1" has the following attributes:
      """
      { "protected": true }
      """
    And the current account has 1 "product"
    And I am a product of account "test1"
    And I use an authentication token
    And the current account has 3 "webhook-endpoints"
    And all "webhook-endpoints" have the following attributes:
      """
      {
        "subscriptions": ["license.created"]
      }
      """
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Ironman",
            "lastName": "Stark",
            "email": "ironman@keygen.sh",
            "password": "jarvis!!"
          }
        }
      }
      """
    Then the response status should be "201"
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 1 "metric" job
    And sidekiq should have 1 "request-log" job

  Scenario: User attempts to create an admin for their account
    Given the current account is "test1"
    And the current account has 2 "webhook-endpoints"
    And the current account has 1 "user"
    And I am a user of account "test1"
    And I use an authentication token
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Superman",
            "lastName": "Kent",
            "email": "superman@keygen.sh",
            "password": "sunlight",
            "role": "admin"
          }
        }
      }
      """
    Then the response status should be "400"
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: User attempts to create a user for a protected account
    Given the current account is "test1"
    And the account "test1" has the following attributes:
      """
      { "protected": true }
      """
    And the current account has 2 "webhook-endpoints"
    And the current account has 1 "user"
    And I am a user of account "test1"
    And I use an authentication token
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Clark",
            "lastName": "Kent",
            "email": "superman@keygen.sh",
            "password": "sunlight"
          }
        }
      }
      """
    Then the response status should be "403"
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: Anonymous attempts to create an admin for an account
    Given the current account is "test1"
    And the current account has 1 "webhook-endpoint"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Thor",
            "lastName": "Thor",
            "email": "thor@keygen.sh",
            "password": "*mjolnir*",
            "role": "admin"
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Bad request",
        "detail": "Unpermitted parameters: /data/attributes/role"
      }
      """
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: Anonymous attempts to create a user with a developer role for an account
    Given the current account is "test1"
    And the current account has 1 "webhook-endpoint"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Thor",
            "lastName": "Thor",
            "email": "thor@keygen.sh",
            "password": "mjolnir?",
            "role": "developer"
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Bad request",
        "detail": "Unpermitted parameters: /data/attributes/role"
      }
      """
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: Anonymous attempts to create a user with a sales agent role for an account
    Given the current account is "test1"
    And the current account has 1 "webhook-endpoint"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Thor",
            "lastName": "Thor",
            "email": "thor@keygen.sh",
            "password": "mjolnir--",
            "role": "sales-agent"
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Bad request",
        "detail": "Unpermitted parameters: /data/attributes/role"
      }
      """
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: Anonymous attempts to create a user with a support agent role for an account
    Given the current account is "test1"
    And the current account has 1 "webhook-endpoint"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Thor",
            "lastName": "Thor",
            "email": "thor@keygen.sh",
            "password": "mjolnir++",
            "role": "support-agent"
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Bad request",
        "detail": "Unpermitted parameters: /data/attributes/role"
      }
      """
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: Anonymous attempts to create a user with a license role for an account
    Given the current account is "test1"
    And the current account has 1 "webhook-endpoint"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Thor",
            "lastName": "Thor",
            "email": "thor@keygen.sh",
            "password": "hunter1",
            "role": "license"
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Bad request",
        "detail": "Unpermitted parameters: /data/attributes/role"
      }
      """
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: Anonymous attempts to create a user with a product role for an account
    Given the current account is "test1"
    And the current account has 1 "webhook-endpoint"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Thor",
            "lastName": "Thor",
            "email": "thor@keygen.sh",
            "password": "hunter1",
            "role": "product"
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Bad request",
        "detail": "Unpermitted parameters: /data/attributes/role"
      }
      """
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: Anonymous attempts to create a user with an admin role for an account (meme casing)
    Given the current account is "test1"
    And the current account has 1 "webhook-endpoint"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Bad",
            "lastName": "Actor",
            "email": "hack@keygen.sh",
            "password": "ugotpwnd",
            "RoLe": "admin"
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Bad request",
        "detail": "Unpermitted parameters: /data/attributes/roLe"
      }
      """
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: Anonymous attempts to create a user with an admin role for an account (caps casing)
    Given the current account is "test1"
    And the current account has 1 "webhook-endpoint"
    When I send a POST request to "/accounts/test1/users" with the following:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "Bad",
            "lastName": "Actor",
            "email": "hack@keygen.sh",
            "password": "ugotpwnd",
            "ROLE": "admin"
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Bad request",
        "detail": "Unpermitted parameters: /data/attributes/role"
      }
      """
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 1 "request-log" job

  Scenario: Anonymous attempts to send a request containing an invalid byte sequence (bad UTF-8 encoding)
    Given the current account is "test1"
    And the current account has 1 "webhook-endpoint"
    When I send a POST request to "/accounts/test1/users" with the following badly encoded data:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "firstName": "String in CP1252 encoding: \xE4\xF6\xFC\xDF",
            "lastName": "Partly valid\xE4 UTF-8 encoding: äöüß",
            "email": "thor@keygen.sh",
            "password": "hunter1",
            "role": "admin"
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Bad request",
        "detail": "The request could not be completed because it contains an invalid byte sequence (check encoding)",
        "code": "ENCODING_INVALID"
      }
      """
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 0 "request-log" jobs

  Scenario: Anonymous attempts to send a request containing a unicode injection
    Given the current account is "test1"
    When I send a POST request to "/accounts/test1/users" with the following badly encoded data:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "email": "bishopfox+blog@keygen.example",
            "password": "json-interoperability-vulnerabilities",
            "role": null,
            "role": "admin\ud888"
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Bad request",
        "detail": "The request could not be completed because it contains an invalid byte sequence (check encoding)",
        "code": "ENCODING_INVALID"
      }
      """
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 0 "request-log" jobs

  Scenario: Anonymous attempts to send a request containing a comment injection (1)
    Given the current account is "test1"
    When I send a POST request to "/accounts/test1/users" with the following badly encoded data:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "email": "bishopfox+blog@keygen.example",
            "password": "json-interoperability-vulnerabilities",
            "firstName": /*,
            "role": "admin",
            "lastName": */
          }
        }
      }
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Bad request",
        "detail": "The request could not be completed because it contains invalid JSON (check formatting/encoding)",
        "code": "JSON_INVALID"
      }
      """
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 0 "request-log" jobs

  Scenario: Anonymous attempts to send a request containing a comment injection (2)
    Given the current account is "test1"
    When I send a POST request to "/accounts/test1/users" with the following badly encoded data:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "email": "bishopfox+blog@keygen.example",
            "password": "json-interoperability-vulnerabilities",
            "firstName": "foo"/*,
            "role": "admin",
            "lastName": "bar"*/
          }
        }
      }
      """
    Then the response status should be "201"
    And the JSON response should be a "user" with the firstName "foo"
    And the JSON response should be a "user" with a nil lastName
    And the JSON response should be a "user" with the role "user"
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 1 "metric" jobs
    And sidekiq should have 1 "request-log" jobs

  Scenario: Anonymous attempts to send a request containing trailing garbage
    Given the current account is "test1"
    When I send a POST request to "/accounts/test1/users" with the following badly encoded data:
      """
      {
        "data": {
          "type": "users",
          "attributes": {
            "email": "bishopfox+blog@keygen.example",
            "password": "json-interoperability-vulnerabilities"
          }
        }
      }=
      """
    Then the response status should be "400"
    And the JSON response should be an array of 1 error
    And the first error should have the following properties:
      """
      {
        "title": "Bad request",
        "detail": "The request could not be completed because it contains invalid JSON (check formatting/encoding)",
        "code": "JSON_INVALID"
      }
      """
    And sidekiq should have 0 "webhook" jobs
    And sidekiq should have 0 "metric" jobs
    And sidekiq should have 0 "request-log" jobs
