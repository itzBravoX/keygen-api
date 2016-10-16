@api/v1
Feature: Update policy

  Background:
    Given the following accounts exist:
      | Name  | Subdomain |
      | Test1 | test1     |
      | Test2 | test2     |
    And I send and accept JSON

  Scenario: Admin updates a policy for their account
    Given I am an admin of account "test1"
    And I am on the subdomain "test1"
    And the current account has 2 "webhookEndpoints"
    And the current account has 1 "policy"
    And I use my authentication token
    When I send a PATCH request to "/policies/$0" with the following:
      """
      { "policy": { "name": "Trial" } }
      """
    Then the response status should be "200"
    And the JSON response should be a "policy" with the name "Trial"
    And sidekiq should have 2 "webhook" jobs

  Scenario: Admin attempts to update a policy for another account
    Given I am an admin of account "test2"
    But I am on the subdomain "test1"
    And the current account has 2 "webhookEndpoints"
    And the account "test1" has 1 "policy"
    And I use my authentication token
    When I send a PATCH request to "/policies/$0" with the following:
      """
      { "policy": { "price": 0 } }
      """
    Then the response status should be "401"
    And sidekiq should have 0 "webhook" jobs

  Scenario: Product updates a policy for their product
    Given I am on the subdomain "test1"
    And the current account has 3 "webhookEndpoints"
    And the current account has 1 "product"
    And I am a product of account "test1"
    And I use my authentication token
    And the current account has 1 "policy"
    And the current product has 1 "policy"
    When I send a PATCH request to "/policies/$0" with the following:
      """
      { "policy": { "price": 1000 } }
      """
    Then the response status should be "200"
    And the JSON response should be a "policy" with the price "1000"
    And sidekiq should have 3 "webhook" jobs

  Scenario: Product attempts to update a policy for another product
    Given I am on the subdomain "test1"
    And the current account has 1 "webhookEndpoint"
    And the current account has 1 "product"
    And I am a product of account "test1"
    And I use my authentication token
    And the current account has 1 "policy"
    When I send a PATCH request to "/policies/$0" with the following:
      """
      { "policy": { "price": 1000 } }
      """
    Then the response status should be "403"
    And sidekiq should have 0 "webhook" jobs
