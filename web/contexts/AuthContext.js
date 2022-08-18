import * as fcl from "@onflow/fcl";
import { createContext, useContext, useEffect, useState } from "react";
import { checkIsInitialized, IS_INITIALIZED } from "../flow/scripts";

export const AuthContext = createContext({});

export const useAuth = () => useContext(AuthContext)

export default function AuthProvider({children}) {

    // Create state variables to keep track of the current users
    const [currentUser, setUser] = useState({
        loggedIn: false,
        addr: undefined,
    })

    // Create state variables to represent if a user's account 
    // Has ben initialized or not
    const [isInitialized, setIsInitialized] = useState(false)

    // Use FCL to subscribe to changes in the user (login,  logout, ect)
    // Tell FLC to call 'setUser' and update our state variables
    // if anything changes
    useEffect(() => fcl.currentUser.subscribe(setUser), []);

    // If current user is logged in,
    // check whether their account is initialized or not an
    useEffect(() => {
        if (currentUser.addr) {
            checkInit();
        }
    }, [currentUser]);

    // Helper function to log out the user
    const logOut = async () => {
        fcl.unauthenticate();
        setUser({ loggedIn: false, addr: undefined });
    }

    // Helpoer function to log the user in to the dapp
    const logIn = () => {
        fcl.logIn();
    };

    // use the checkIsInitialized function
    // and update teh state variables was necessary
    const checkInit = async () => {
        const isInit = await checkIsInitialized(currentUser.addr)
        setIsInitialized(isInit)
    }

    const value = {
        currentUser,
        isInitialized,
        checkInit, 
        logOut,
        logIn
    }

    // Return teh context provider with the value set
    // Render all children of the component inside of initialized
    return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
