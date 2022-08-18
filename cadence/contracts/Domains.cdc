import FungibleToken from "./interfaces/FungibleToken.cdc"
import NonFungibleToken from "./interfaces/NonFungibleToken.cdc"
import FlowToken from "./tokens/FlowToken.cdc"

// The Domains contracts defines the Domian NFT Collection
// to be used by the naming service

pub contract Domains: NonFungibleToken {

    // Defines forbidden characters within domain names - such as . 
    pub let forbiddenChars: String
    pub let owners: {String: Address}
    pub let expirationTimes: {String: UFix64}
    pub let nameHashToIDs: {String: UInt64}
    pub var totalSupply: UInt64



    // Storage, Public, and Private paths for Domains.Collection resource
    pub let DomainsStoragePath: StoragePath
    pub let DomainsPrivatePath: PrivatePath
    pub let DomainsPublicPath: PublicPath

    // Storage, Public and Private paths for Domains.Registrar resource
    pub let RegistrarStoragePath: StoragePath
    pub let RegistrarPrivatePath: PrivatePath
    pub let RegistrarPublicPath: PublicPath

    // Event that implies a contract has been initialized
    pub event ContractInitialized()
    pub event DomainBioChanged(nameHash: String, bio: String)
    pub event DomainAddressChanged(nameHash: String, address: Address)

    // Events to emit when a domain is renewed and rented for longer
    pub event DomainMinted(id: UInt64, name: String, nameHash: String, expiresAt: UFix64, receiver: Address)
    pub event DomainRenewed(id: UInt64, name: String, nameHash: String, expiresAt: UFix64, receiver: Address)
    
    // Required by the NonFungibleToken standard
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

     // Initializer
    init() {
        // Initial values for dictionaries is an empty dictionary
        self.owners = {}
        self.expirationTimes = {}
        self.nameHashToIDs = {}
        
        // Define forbidden characters for domain names
        self.forbiddenChars = "!@#$%^&*()<>? ./"
        // initialize total supply to 0 
        self.totalSupply = 0

        // Set the various paths to store Domains.Collection at in a users account
        self.DomainsStoragePath = StoragePath(identifier: "flowNameServiceDomains") ?? panic("Could not set storage path")
        self.DomainsPrivatePath = PrivatePath(identifier: "flowNameServiceDomains") ?? panic("Cloud not set private path")
        self.DomainsPublicPath = PublicPath(identifier: "flowNameServiceDomains") ?? panic("Could not set public path")

        // Set teh various paths to store 'Domain.Registrar at in a users account storage
        self.RegistrarStoragePath = StoragePath(identifier: "flowNameServiceRegistrar") ?? panic("Could not set storage path")
        self.RegistrarPrivatePath = PrivatePath(identifier: "flowNameServiceRegistrar") ?? panic("Could not set private path")
        self.RegistrarPublicPath = PublicPath(identifier: "flowNameServiceRegistrar") ?? panic("Coud not set private path")

       
    
        // self.account refers to the account where the smart contract lives
        // i.e. the admin account
        // 1. Create an empty Domains.Collection resource
        // 2. Save it to the admin account's storage path

        self.account.save(<- self.createEmptyCollection(), to: Domains.DomainsStoragePath)

        // 3. Link the Public resource interfaces that we are okay with sharing with third-parties
        // to the pyblic account storage from the main stroage path
        // all objects in the public paths can be accessed by anyone

        self.account.link<&Domains.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, Domains.CollectionPublic}>(self.DomainsPublicPath,target: self.DomainsStoragePath)

        // 4. Link the overall resource (public + private ) to the 
        // private storage path from the main stroage paths
        // This allows us to create capabilities if necessarty
        // Thi sis needed because Capabilites can only be created from 
        // public or private paths, not from the main storage path
        // for security reasons 

        self.account.link<&Domains.Collection>(self.DomainsPrivatePath, target: self.DomainsStoragePath)

        // Now get a capability from teh priavte path for Domains.Collections
        // from the admin account
        // we will pass this onto the Registrar resource (to be created)
        // So it has access to the Private Funtions within Domains.Collection
        // Specifically mintDomain
        
        let collectionCapability = self.account.getCapability<&Domains.Collection>(self.DomainsPrivatePath)

        // Create an empty FungibleToken.Vault for the Flowtoken
        // THis is the one and only time we utilize the FlowToken import 

        let vault <- FlowToken.createEmptyVault()

        // Create Registrar resource and give it to the Vault
        // and the Private Collection Capability

        let registrar <- create Registrar(vault: <- vault, collection: collectionCapability)
        // now save teh Registrar resource in the admin accounts main storage path
        self.account.save(<- registrar, to: self.RegistrarStoragePath)
        // Link the Public portion of the Registar to the public paths
        // self.account.link<&Domains.Registrar{Domains.RegistrarPublic}>(self.RegistrarPublicPath, target: self.RegistrarStoragePath)
        self.account.link<&Domains.Registrar{Domains.RegistrarPublic}>(self.RegistrarPublicPath, target: self.RegistrarStoragePath)
        // for the Registrar resource
        //self.account.link<&Domains.Registrar>(self.RegistrarPrivatePath, target: self.RegistrarStoragePath)
        self.account.link<&Domains.Registrar>(self.RegistrarPrivatePath, target: self.RegistrarStoragePath)

        // Emit the ContractInitialized even 
        emit ContractInitialized()
    }


    // Struct that represents information about an FNS domain
    pub struct DomainInfo {
        // Public Variables of the stuct Domian
        pub let id: UInt64
        pub let owner: Address
        pub let name: String
        pub let nameHash: String
        pub let expiresAt: UFix64
        pub let address: Address?
        pub let bio: String
        pub let createdAt: UFix64

        // Struct initalizer
        init(
            id: UInt64,
            owner: Address,
            name: String,
            nameHash: String,
            expiresAt: UFix64,
            address: Address?,
            bio: String,
            createdAt: UFix64
        ) {
            self.id = id
            self.owner = owner
            self.name = name
            self.nameHash = nameHash
            self.expiresAt = expiresAt
            self.address = address
            self.bio = bio
            self.createdAt = createdAt
        }
    }
    
    // Interfaces Domain
    pub resource interface DomainPublic {
        pub let id: UInt64
        pub let name: String
        pub let nameHash: String
        pub let createdAt: UFix64

        pub fun getBio(): String
        pub fun getAddress(): Address?
        pub fun getDomainName(): String
        pub fun getInfo(): DomainInfo
    }

    pub resource interface DomainPrivate {
        pub fun setBio(bio: String)
        pub fun setAddress(addr: Address)
    }

    pub resource NFT: DomainPublic, DomainPrivate, NonFungibleToken.INFT {
        pub let id: UInt64
        pub let name: String
        pub let nameHash: String
        pub let createdAt: UFix64

        // access(self) implies that only the code within this resource
        // can read/modify this variable directly
        // This is similar to `private` in Solidity

        access(self) var address: Address?
        access(self) var bio: String

        init(id: UInt64, name: String, nameHash: String) {
        self.id = id
        self.name = name
        self.nameHash = nameHash
        self.createdAt = getCurrentBlock().timestamp
        self.address = nil
        self.bio = ""
        }

    pub fun getBio(): String {
        return self.bio
    }

    pub fun setBio(bio: String) {
      pre {
        Domains.isExpired(nameHash: self.nameHash) == false : "Domain is expired"
      }
      self.bio = bio
      emit DomainBioChanged(nameHash: self.nameHash, bio: bio)
    }

    pub fun getAddress(): Address? {
      return self.address
    }

    pub fun setAddress(addr: Address) {
      pre {
        Domains.isExpired(nameHash: self.nameHash) == false : "Domain is expired"
      }

      self.address = addr
      emit DomainAddressChanged(nameHash: self.nameHash, address: addr)
    }

    pub fun getDomainName(): String {
      return self.name.concat(".fns")
    }

    pub fun getInfo(): DomainInfo {
      let owner = Domains.owners[self.nameHash]!

      return DomainInfo(
        id: self.id,
        owner: owner,
        name: self.getDomainName(),
        nameHash: self.nameHash,
        expiresAt: Domains.expirationTimes[self.nameHash]!,
        address: self.address,
        bio: self.bio,
        createdAt: self.createdAt
            )
        }
    }

    // resource interface Collection

    // NonFungibleToken.CollectionPublic
    pub resource interface CollectionPublic {
        pub fun borrowDomain(id: UInt64): &{Domains.DomainPublic}
    }
    // NonFungibleToken.CollectionPrivate
    pub resource interface CollectionPrivate {
        access(account) fun mintDomain(name: String, nameHash: String, expiresAt: UFix64, receiver: Capability<&{NonFungibleToken.Receiver}>)
        pub fun borrowDomainPrivate(id: UInt64): &Domains.NFT
    }

    // Collection
    pub resource Collection: CollectionPublic, CollectionPrivate, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {

        // Dictionary (mapping) of Token ID -> NFT Resource;
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            // Initialize as an empty Resource
            self.ownedNFTs <- {}
        }

        // NonFungibleToken.Provider
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let domain <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("NFT not found in collection")
            emit Withdraw(id: domain.id, from: self.owner?.address)
            return <- domain
        }
        // NonFungibleToken.Receiver
        pub fun deposit(token: @NonFungibleToken.NFT) {
            // Type cast the generic NFT resource as Domains.NFT resource
            let domain <- token as! @Domains.NFT
            let id = domain.id
            let nameHash = domain.nameHash

            if Domains.isExpired(nameHash: nameHash) {
                panic("Domain is expired")
            }

            Domains.updateOwner(nameHash: nameHash, address: self.owner!.address)

            let oldToken <- self.ownedNFTs[id] <- domain
            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken

        }

        // NonFungibleToken.CollectionPublic
        pub fun getIDs(): [UInt64] {
            // return keys which are set in a mapping
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!

        }

        // Domains.CollectionPublic
        pub fun borrowDomain(id: UInt64): &{Domains.DomainPublic} {
            pre {
                self.ownedNFTs[id] != nil : "Domain does not exist"
            }
            let token = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            return token as! &Domains.NFT
        }
        // Domains.CollectionPrivate
        access(account) fun mintDomain(name: String, nameHash: String, expiresAt: UFix64, receiver: Capability<&{NonFungibleToken.Receiver}>){
            pre {
                Domains.isAvailable(nameHash: nameHash) : "Domain not available"
            }

            let domain <- create Domains.NFT(
                id: Domains.totalSupply,
                name: name,
                nameHash: nameHash
            )

            Domains.updateOwner(nameHash: nameHash, address: receiver.address)
            Domains.updateExpirationTime(nameHash: nameHash, expTime: expiresAt)
            Domains.updateNameHashToID(nameHash: nameHash, id: domain.id)
            Domains.totalSupply = Domains.totalSupply + 1

            emit DomainMinted(id: domain.id, name: name, nameHash: nameHash, expiresAt: expiresAt, receiver: receiver.address)

            receiver.borrow()!.deposit(token: <- domain)
        }

        pub fun borrowDomainPrivate(id: UInt64): &Domains.NFT {
            pre {
                self.ownedNFTs[id] != nil: "domain doesn't exist"
            }
            let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            return ref as! &Domains.NFT
        }

        destroy() {
            destroy self.ownedNFTs
    }
  }

  // Registrar Interfaces
    pub resource interface RegistrarPublic {
        pub let minRentDuration: UFix64
        pub let maxDomainLength: Int
        pub let prices: {Int: UFix64}

        pub fun renewDomain(domain: &Domains.NFT, duration: UFix64, feeTokens: @FungibleToken.Vault)
        pub fun registerDomain(name: String, duration: UFix64, feeTokens: @FungibleToken.Vault, receiver: Capability<&{NonFungibleToken.Receiver}>)
        pub fun getPrices(): {Int: UFix64}
        pub fun getVaultBalance(): UFix64
    }

    // RegistrarPrivate

    pub resource interface RegistrarPrivate {
        pub fun updateRentVault(vault: @FungibleToken.Vault)
        pub fun withdrawVault(receiver: Capability<&{FungibleToken.Receiver}>, amount: UFix64)
        pub fun setPrices(key: Int, val: UFix64)
    }

    pub resource Registrar: RegistrarPublic, RegistrarPrivate {

        // Variables defined in teh interfaces
        pub let minRentDuration: UFix64
        pub let maxDomainLength: Int
        pub let prices: {Int: UFix64}



        // A reference to teh Valt used for depositing Flow tokens we receive
        // 'priv' variables cannot be defined in interfaces
        // 'priv' = 'private' it is shorthand for access(self)
        priv var rentVault: @FungibleToken.Vault

        // A Capability for the Domains.Collection resource owned by the account
        // Only the account has acess to it 
        // We will used this to access the acount-ohnly mintDomain function
        // Within the Collection owned by our smart contract account
        access(account) var domainsCollection: Capability<&Domains.Collection>

        init(vault: @FungibleToken.Vault, collection: Capability<&Domains.Collection>) {
            // This is one year in seconds
            self.minRentDuration = UFix64(365 * 24 * 60 * 60)
            self.maxDomainLength = 30
            self.prices = {}

            self.rentVault <- vault
            self.domainsCollection = collection
        }

        // Renew the Domain
        pub fun renewDomain(domain: &Domains.NFT, duration: UFix64, feeTokens: @FungibleToken.Vault) {
            // We don't need to check if the user owns this domain
            // because they are providing us a full reference to Domains.NFT
            // througth the first arguemnt
            // They could not have done this if they did not own the domain 
            var len = domain.name.length
            // if the length of the domain name is > 10
            // Make the arbitrary decision to price it the same way
            // as if it was 10 characters long
            if len > 10 {
                len = 10
            }

            // Get the price per second of rental for this length of domain
            let price = self.getPrices()[len]

            // Ensure that the duration to rent for isn't less than the minimum
            if duration < self.minRentDuration {
                panic("Domain must be registered for at least the minimum duration: ".concat(self.minRentDuration.toString()))
            }
            // Ensure thatthe admin has set a price for this domain length
            if price == 0.0 || price == nil {
                panic("Price has not been set for this length of domain")
            }

            // Calculate total rental cost (price * duration)
            let rentCost = price! * duration
            // Check the balance of the Vault given to us by hte user
            // This is their way of sending us tokens through the transaction
            let feeSent = feeTokens.balance

            if feeSent < rentCost {
                panic("You did not send enough FLOW tokens. Expected: ".concat(rentCost.toString()))
            }
            // If yes, deposit those tokens into our own rentVault
            self.rentVault.deposit(from: <- feeTokens)

            // Calculate the new expiration date for his domain
            // Add duration of rental to current expiry date 
            // and update teh expiration time
            let newExpTime = Domains.getExpirationTime(nameHash: domain.nameHash)! + duration
            Domains.updateExpirationTime(nameHash: domain.nameHash, expTime: newExpTime)

            // emit the Domainrenewed event
            emit DomainRenewed(id: domain.id, name: domain.name, nameHash: domain.nameHash, expiresAt: newExpTime, receiver: domain.owner!.address)
        }
    
    // Register Domains
    pub fun registerDomain(name: String, duration: UFix64, feeTokens: @FungibleToken.Vault, receiver: Capability<&{NonFungibleToken.Receiver}>) {
        // Ensure teh domain is not longer than the max length allowed for
        pre {
            name.length <= self.maxDomainLength : "Domain name is tooo long"
        }
        // Hash the name and get the nameHash
        // we have not yet implemented this function, will do so right after this sectiono 
        let nameHash = Domains.getDomainNameHash(name: name)

        // Ensure the domain is available for sale
        if Domains.isAvailable(nameHash: nameHash) == false {
            panic("Domain is not available")
        }

            // Same as renew, price any domain > 10 characters the same way
            // as a domain with 10 characters
        var len = name.length
        if len > 10 {
            len = 10
        }

        // All the calculations are teh same as renew
        let price = self.getPrices()[len]

        if duration < self.minRentDuration {
            panic("Domain must be registered for at least the minimum duration: ".concat(self.minRentDuration.toString()))
        }

        if price == 0.0 || price == nil {
            panic("Price has not been set for this length of domain")
        }

        let rentCost = price! * duration
        let feeSent = feeTokens.balance

        if feeSent < rentCost {
            panic("You did not send enough FLOW tokens, Expected: ".concat(rentCost.toString()))
        }

        self.rentVault.deposit(from: <- feeTokens)

        // Calculate the expirty time for the domain by adding durationo 
        // to th ecurrent timestamp
        let expirationTime = getCurrentBlock().timestamp + duration
            
        // use the domainCollection capability of the admin to mint the new domain
        // and transfer it to the receiver
        self.domainsCollection.borrow()!.mintDomain(name: name, nameHash: nameHash, expiresAt: expirationTime, receiver: receiver)
        // DomianMinted event is emitted from mintDomain ^
        }

         // Return prices dictionary
        pub fun getPrices(): {Int: UFix64} {
            return self.prices
        }

        // Return the balanc of our rentVault
        pub fun getVaultBalance(): UFix64 {
            return self.rentVault.balance
        }

        // update the rentVault to point to a different vault
        pub fun updateRentVault(vault: @FungibleToken.Vault) {
        // Make sure current vault doesn't have any remaining tokens before updating it
            pre {
                self.rentVault.balance == 0.0 : "Withdraw balance from old vault before updating"
            }

            // Simutaneously move the old vault out and teh new vault in 
            let oldVault <- self.rentVault <- vault
            // Destroy the old vault 
            destroy oldVault
        }

        // Move tokens from out rentVault to the given FungibleToken.Receiver
        pub fun withdrawVault(receiver: Capability<&{FungibleToken.Receiver}>, amount: UFix64) {
            let vault = receiver.borrow()!
            vault.deposit(from: <- self.rentVault.withdraw(amount: amount))

        }

        // update prices of domains for a given length  
        pub fun setPrices(key: Int, val: UFix64) {
            self.prices[key] = val
        }

        destroy() {
            destroy self.rentVault
        }

    }

    // Global Variables

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        let collection <- create Collection()
        return <- collection
    }

    // Registrar the Domain
    pub fun registerDomain(name: String, duration: UFix64, feeTokens: @FungibleToken.Vault, receiver: Capability<&{NonFungibleToken.Receiver}>) {
        let cap = self.account.getCapability<&Domains.Registrar{Domains.RegistrarPublic}>(self.RegistrarPublicPath)
        let registrar = cap.borrow() ?? panic("Could no borrow registrar")
        registrar.registerDomain(name: name, duration: duration, feeTokens: <- feeTokens, receiver: receiver)
    }

    // Renew Domain Domain
    pub fun renewDomain(domain: &Domains.NFT, duration: UFix64, feeTokens: @FungibleToken.Vault) {
        let cap = self.account.getCapability<&Domains.Registrar{Domains.RegistrarPublic}>(self.RegistrarPublicPath)
        let registrar = cap.borrow() ?? panic("Could no borrow registrar")
        registrar.renewDomain(domain: domain, duration: duration, feeTokens: <- feeTokens)
    }
    // Get rent cost
    pub fun getRentCost(name: String, duration: UFix64): UFix64 {
        var len = name.length
        if len > 10 {
            len = 10
        }

        let price = self.getPrices()[len]

        let rentCost = price! * duration
        return rentCost
    }

    pub fun getDomainNameHash(name: String): String {
        /// Make sure the domain name doesn't have any illegal characters
        let forbiddenCharsUFT8 = self.forbiddenChars.utf8
        let nameUTF8 = name.utf8

        for char in forbiddenCharsUFT8 {
            if nameUTF8.contains(char) {
                panic("Illegal domain name")
            }
        }

        // Calculate the SHA-256 hash, and encode it as a Hexadecimal String
        let nameHash = String.encodeHex(HashAlgorithm.SHA3_256.hash(nameUTF8))
        return nameHash
    }

    // Checks if a domain is available for sale
    pub fun isAvailable(nameHash: String): Bool {
        if self.owners[nameHash] == nil {
      return true
        }
    return self.isExpired(nameHash: nameHash)
    }

    // get prices
    pub fun getPrices(): {Int: UFix64} {
        let cap = self.account.getCapability<&Domains.Registrar{Domains.RegistrarPublic}>(Domains.RegistrarPublicPath)
        let collection = cap.borrow() ?? panic("Could not borrow collection")
        return collection.getPrices()
    } 
    
    // get vault
    pub fun getVaultBalance(): UFix64 {
        let cap = self.account.getCapability<&Domains.Registrar{Domains.RegistrarPublic}>(Domains.RegistrarPublicPath)
        let registrar = cap.borrow() ?? panic("Could no borrow registrar public")
        return registrar.getVaultBalance()
    }

    // Returns the expiry time for a domain
    pub fun getExpirationTime(nameHash: String): UFix64? {
        return self.expirationTimes[nameHash]
    }  

    // Checks if a domain is expired
    pub fun isExpired(nameHash: String): Bool {
        let currTime = getCurrentBlock().timestamp
        let expTime = self.expirationTimes[nameHash]
        if expTime != nil {
            return currTime >= expTime!
        }
        return false
    } 

    // Returns the entire `owners` dictionary
    pub fun getAllOwners(): {String: Address} {
        return self.owners
    }

    // Returns the entire `expirationTimes` dictionary
    pub fun getAllExpirationTimes(): {String: UFix64} {
        return self.expirationTimes
    }

    pub fun getAllNamesHashToIDs(): {String: UInt64} {
        return self.nameHashToIDs
    }
    
    // Update the owner of a domain
    access(account) fun updateOwner(nameHash: String, address: Address) {
        self.owners[nameHash] = address
    }

    // Update the expirationTimes of a domain
    access(account) fun updateExpirationTime(nameHash: String, expTime: UFix64) {
        self.expirationTimes[nameHash] = expTime
    }

    access(account) fun updateNameHashToID(nameHash: String, id: UInt64) {
        self.nameHashToIDs[nameHash] = id
    }
    
}

