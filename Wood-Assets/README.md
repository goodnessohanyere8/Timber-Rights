# Timber Rights Tokenization Smart Contract

This Clarity smart contract facilitates the tokenization and management of timber rights on the Stacks blockchain. It provides a comprehensive framework for creating, trading, verifying, and managing timber parcels, including functionalities for harvest reporting and proceeds distribution.

## Features

*   **Timber Parcel Creation**: Allows owners to register new timber parcels with detailed attributes like location, species, estimated volume, planting/harvest dates, and certification.
*   **Tokenization**: Each timber parcel is tokenized, representing a share of the timber rights.
*   **Token Trading**: Users can purchase and transfer timber tokens.
*   **Parcel Verification**: Authorized verifiers can mark timber parcels as verified.
*   **Harvest Reporting**: Authorized verifiers can submit detailed harvest reports for mature parcels.
*   **Proceeds Claiming**: Token holders can claim their proportional share of harvest proceeds once a parcel is harvested.
*   **User Profiles**: Tracks basic user reputation and transaction counts.
*   **Admin Controls**: Contract owner can pause/unpause the contract, manage authorized verifiers, and update the base token price.
*   **Metadata Management**: Allows parcel owners to update metadata URI for their parcels.

## Contract Details

### Token

*   `timber-rights-token`: A fungible token defined within the contract. Each unit of this token represents a share of timber rights for a specific parcel.

### Constants

| Constant                 | Value | Description                                                              |
| :----------------------- | :---- | :----------------------------------------------------------------------- |
| `CONTRACT_OWNER`         | `tx-sender` | The principal that deployed the contract.                                |
| `ERR_UNAUTHORIZED`       | `u100` | Caller does not have the necessary permissions.                          |
| `ERR_NOT_FOUND`          | `u101` | The requested resource (e.g., parcel) was not found.                     |
| `ERR_ALREADY_EXISTS`     | `u102` | The resource already exists (not explicitly used in current version).    |
| `ERR_INVALID_AMOUNT`     | `u103` | An invalid amount was provided (e.g., zero or negative where not allowed). |
| `ERR_INSUFFICIENT_BALANCE` | `u104` | Insufficient token balance for the operation.                            |
| `ERR_INVALID_PERIOD`     | `u105` | Invalid planting/harvest dates provided.                                 |
| `ERR_EXPIRED`            | `u106` | The operation is not allowed because a period has expired.               |
| `ERR_NOT_MATURE`         | `u107` | The timber parcel is not yet mature for harvest.                         |
| `ERR_INVALID_COORDINATES`| `u108` | Invalid geographical coordinates provided.                               |
| `ERR_INVALID_SPECIES`    | `u109` | Invalid tree species string provided.                                    |
| `ERR_TRANSFER_FAILED`    | `u110` | STX transfer failed.                                                     |
| `ERR_INVALID_INPUT`      | `u111` | General error for invalid input data (e.g., empty strings, self-transfer). |

### Data Variables

*   `total-parcels` (uint): Stores the total number of timber parcels created. Used to generate new parcel IDs.
*   `contract-paused` (bool): A flag indicating if the contract's core functionalities (like creating parcels or purchasing tokens) are paused by the owner.
*   `base-token-price` (uint): A base price in microSTX used in calculating harvest proceeds.

### Data Maps

*   `timber-parcels` (map `uint` to `{...}`): Stores detailed information about each timber parcel, indexed by `parcel-id`.
    *   `owner`: `principal` - The owner of the parcel.
    *   `location-lat`: `int` - Latitude of the parcel location (e.g., in microdegrees).
    *   `location-lng`: `int` - Longitude of the parcel location (e.g., in microdegrees).
    *   `area-hectares`: `uint` - Area of the parcel in hectares.
    *   `tree-species`: `(string-ascii 50)` - Type of tree species.
    *   `estimated-volume`: `uint` - Estimated timber volume.
    *   `planting-date`: `uint` - Unix timestamp of the planting date.
    *   `harvest-date`: `uint` - Unix timestamp of the estimated harvest date.
    *   `certification`: `(string-ascii 100)` - Certification details (e.g., FSC, PEFC).
    *   `token-supply`: `uint` - Total number of tokens issued for this parcel.
    *   `available-tokens`: `uint` - Number of tokens currently available for purchase from the parcel owner.
    *   `price-per-token`: `uint` - Price of one token for this parcel (in microSTX).
    *   `is-verified`: `bool` - True if the parcel has been verified by an authorized verifier.
    *   `is-harvested`: `bool` - True if a harvest report has been submitted for this parcel.
    *   `metadata-uri`: `(optional (string-ascii 256))` - URI pointing to off-chain metadata (e.g., IPFS).

*   `user-balances` (map `{ user: principal, parcel-id: uint }` to `uint`): Stores the balance of timber tokens for a specific user and parcel.

*   `parcel-transactions` (map `uint` to `{...}`): Records details of token purchase transactions, indexed by `parcel-id`.
    *   `buyer`: `principal` - The buyer of the tokens.
    *   `seller`: `principal` - The seller of the tokens.
    *   `token-amount`: `uint` - Number of tokens transferred.
    *   `price`: `uint` - Total STX price of the transaction.
    *   `timestamp`: `uint` - Unix timestamp of the transaction.

*   `harvest-reports` (map `uint` to `{...}`): Stores harvest reports for parcels, indexed by `parcel-id`.
    *   `parcel-id`: `uint` - The ID of the harvested parcel.
    *   `actual-volume`: `uint` - Actual harvested timber volume.
    *   `harvest-date`: `uint` - Unix timestamp of the actual harvest.
    *   `certifier`: `principal` - The authorized verifier who submitted the report.
    *   `sustainability-score`: `uint` - A score indicating sustainability (e.g., 0-100).
    *   `report-uri`: `(string-ascii 256)` - URI pointing to the full harvest report.

*   `user-profiles` (map `principal` to `{...}`): Stores basic profile information for users.
    *   `reputation-score`: `uint` - A simple reputation score (initialized to 100).
    *   `total-transactions`: `uint` - Count of transactions made by the user.
    *   `verified-status`: `bool` - Indicates if the user's profile is verified (currently always false, can be extended).
    *   `join-date`: `uint` - Unix timestamp when the user's profile was initialized.

*   `authorized-verifiers` (map `principal` to `bool`): A whitelist of principals authorized to verify parcels and submit harvest reports.

## Functions

### Read-Only Functions

These functions allow querying the contract state without incurring transaction fees.

*   `(get-parcel-info (parcel-id uint))`: Returns the full data of a timber parcel or `none` if not found.
*   `(get-user-balance (user principal) (parcel-id uint))`: Returns the token balance for a specific user and parcel.
*   `(get-total-parcels)`: Returns the total number of timber parcels created.
*   `(get-contract-paused)`: Returns `true` if the contract is paused, `false` otherwise.
*   `(get-user-profile (user principal))`: Returns the profile data for a given user or `none` if not found.
*   `(get-harvest-report (parcel-id uint))`: Returns the harvest report for a given parcel or `none` if not found.
*   `(is-authorized-verifier (verifier principal))`: Returns `true` if the principal is an authorized verifier, `false` otherwise.
*   `(calculate-token-value (parcel-id uint) (token-amount uint))`: Calculates the STX value of a given amount of tokens for a specific parcel.
*   `(get-parcel-maturity (parcel-id uint))`: Returns `true` if the parcel's harvest date has passed, `false` otherwise.

### Public Functions

These functions modify the contract state and require a transaction.

*   `(initialize-profile)`: Initializes a user's profile if it doesn't already exist.
*   `(create-timber-parcel (location-lat int) (location-lng int) (area-hectares uint) (tree-species (string-ascii 50)) (estimated-volume uint) (planting-date uint) (harvest-date uint) (certification (string-ascii 100)) (token-supply uint) (price-per-token uint) (metadata-uri (optional (string-ascii 256))))`: Creates a new timber parcel and issues tokens to the `tx-sender`.
*   `(purchase-tokens (parcel-id uint) (token-amount uint))`: Allows a user to purchase tokens for a specific parcel from its owner. Transfers STX from buyer to seller.
*   `(transfer-tokens (recipient principal) (parcel-id uint) (token-amount uint))`: Allows a token holder to transfer tokens to another user.
*   `(verify-parcel (parcel-id uint))`: Allows an authorized verifier to mark a parcel as verified.
*   `(submit-harvest-report (parcel-id uint) (actual-volume uint) (sustainability-score uint) (report-uri (string-ascii 256)))`: Allows an authorized verifier to submit a harvest report for a mature parcel.
*   `(claim-harvest-proceeds (parcel-id uint))`: Allows a token holder to claim their proportional share of STX proceeds from a harvested parcel. Consumes the user's tokens for that parcel.

### Admin Functions

These functions can only be called by the `CONTRACT_OWNER`.

*   `(add-authorized-verifier (verifier principal))`: Adds a principal to the list of authorized verifiers.
*   `(remove-authorized-verifier (verifier principal))`: Removes a principal from the list of authorized verifiers.
*   `(pause-contract)`: Pauses core contract functionalities.
*   `(unpause-contract)`: Unpauses core contract functionalities.
*   `(update-base-token-price (new-price uint))`: Updates the `base-token-price` used in harvest proceeds calculation.
*   `(update-parcel-metadata (parcel-id uint) (new-metadata-uri (string-ascii 256)))`: Allows the parcel owner to update the metadata URI for their parcel.

### Private Functions

These are internal helper functions not directly callable by external users.

*   `(is-valid-coordinates (lat int) (lng int))`: Checks if the provided latitude and longitude are within valid ranges.
*   `(is-valid-tree-species (species (string-ascii 50)))`: Checks if the provided tree species string is not empty.
*   `(update-user-profile (user principal))`: Increments the total transaction count for a user's profile.

## Error Codes

| Code | Name                       | Description                                                              |
| :--- | :------------------------- | :----------------------------------------------------------------------- |
| `u100` | `ERR_UNAUTHORIZED`         | Caller does not have the necessary permissions.                          |
| `u101` | `ERR_NOT_FOUND`            | The requested resource (e.g., parcel) was not found.                     |
| `u102` | `ERR_ALREADY_EXISTS`       | The resource already exists.                                             |
| `u103` | `ERR_INVALID_AMOUNT`       | An invalid amount was provided (e.g., zero or negative where not allowed). |
| `u104` | `ERR_INSUFFICIENT_BALANCE` | Insufficient token balance for the operation.                            |
| `u105` | `ERR_INVALID_PERIOD`       | Invalid planting/harvest dates provided.                                 |
| `u106` | `ERR_EXPIRED`              | The operation is not allowed because a period has expired.               |
| `u107` | `ERR_NOT_MATURE`           | The timber parcel is not yet mature for harvest.                         |
| `u108` | `ERR_INVALID_COORDINATES`  | Invalid geographical coordinates provided.                               |
| `u109` | `ERR_INVALID_SPECIES`      | Invalid tree species string provided.                                    |
| `u110` | `ERR_TRANSFER_FAILED`      | STX transfer failed.                                                     |
| `u111` | `ERR_INVALID_INPUT`        | General error for invalid input data (e.g., empty strings, self-transfer). |

## Usage

To interact with this smart contract, you will need a Stacks wallet and a development environment set up with Clarinet.

1.  **Deployment**: Deploy the `timber-rights-token.clar` contract to a Stacks network (e.g., testnet or mainnet).
2.  **Interaction**: Use the Stacks.js library or Clarinet's console to call the public and read-only functions.

    Example (using Clarinet console):