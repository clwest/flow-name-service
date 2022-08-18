import { useRouter } from "next/router"
import { useEffect, useState } from "react"
import { useAuth } from "../../contexts/AuthContext"
import * as fcl from "@onflow/fcl"
import Head from "next/head";
import Navbar from "../../components/Navbar"
import { getDomainInfoByNameHash, getRentCost } from "../../flow/scripts";
import styles from "../../styles/ManageDomain.module.css"
import { 
    renewDomain,
    updateAddressForDomain,
    updateBioForDomain,
} from "../../flow/transactions"


// constant for 1 year in seconds 
const SECONDS_PER_YEAR = 365 * 24 * 60 * 60;

export default function ManageDomain() {
    // AuthContext to gather data for current user
    const { currentUser, isInitialized } = useAuth();

    // Next Router to get access to nameHash query param
    const router = useRouter();
    // Store the domainInfo
    const [domainInfo, setDomainInfo] = useState();
    // Store bio given users
    const [bio, setBio] = useState("");
    // Store teh address of the users
    const [linkedAddr, setLinkedAddr] = useState("");
    // Store how many years to renew for 
    const [renewFor, setRenewFor] = useState(1);
    // Loading state
    const [loading, setLoading] = useState(false)
    // Set cost for renewal
    const [cost, setCost] = useState(0.0)
    
    // function to load the domain info
    async function loadDomainInfo() {
        try {
            const info = await getDomainInfoByNameHash(
                currentUser.addr,
                router.query.nameHash
            );
            console.log(info)
            setDomainInfo(info)
        } catch (error) {
            console.error(error)
        }
    }

    // Function which will update the bio transactions
    async function updateBio() {
        try {
            setLoading(true);
            const txId = await updateBioForDomain(router.query.nameHash, bio);
            await fcl.tx(txId).onceSealed()
            await loadDomainInfo();
        } catch (error) {
            console.error(error)
        } finally {
            setLoading(false)
        }
    }

    // Function to update the adress transactions
    async function updateAddress() {
        try {
            setLoading(true);
            const txId = await updateAddressForDomain(
                router.query.nameHash,
                linkedAddr
            );
            await fcl.tx(txId).onceSealed();
            await loadDomainInfo()
        } catch (error) {
            console.error(error)
        } finally {
            setLoading(false)
        }
    }

    // Function which runs teh renewal transactions
    async function renew() {
        try {
            setLoading(true);
            if (renewFor <= 0 )
                throw new Error("Must be renewing for at least one year ")
            const duration = (renewFor * SECONDS_PER_YEAR).toFixed(1).toString()
            const txId = await renewDomain(
                domainInfo.name.replace(".fns", ""),
                duration
            );
            await fcl.tx(txId).onceSealed();
            await loadDomainInfo();
        } catch (error) {
            console.error(error)
        } finally {
            setLoading(false);
        }
    }

    // Calculates cost of renewal
    async function getCost() {
        if (domainInfo && domainInfo.name.replace(".fns", "").length > 0 && renewFor > 0) {
            const duration = (renewFor * SECONDS_PER_YEAR).toFixed(1).toString();
            const c = await getRentCost(
                domainInfo.name.replace(".fns", ""),
                duration
            );
            setCost(c);
        }
    }

    // Load domain info if user ia initialized and page is loaded 
    useEffect(() => {
        if (router && router.query && isInitialized) {
            loadDomainInfo();
        }
    }, [router])

    // Calculates cost everytime domainInfo or duration changes
    useEffect(() => {
        getCost();
    }, [domainInfo, renewFor]);

    if (!domainInfo) return null;

    return (
        <div className={styles.container}>
            <Head>
                <title>Flow Name Service - Manage Domain</title>
                <meta name="description" content="Flow Name Service" />
                <link rel="icon" href="/favicon.ico" />
            </Head>

            <Navbar />

            <main className={styles.main}>
                <div>
                    <h1>{domainInfo.name}</h1>
                    <p>ID: {domainInfo.id}</p>
                    <p>Owner: {domainInfo.owner}</p>
                    <p>
                        Created At: {" "}
                        {new Date(
                            parseInt(domainInfo.createdAt) * 1000
                        ).toLocaleDateString()}
                    </p>
                    <p>
                        Expires At: {" "}
                        {new Date(
                            parseInt(domainInfo.expiresAt) * 1000
                        ).toLocaleDateString()}
                    </p>
                    <hr />
                    <p>Bio: {domainInfo.bio ? domainInfo.bio : "Not Set"}</p>
                    <p>Address: {domainInfo.address ? domainInfo.address : " Not Set "}</p>
                </div>

                <div>
                    <h1>Update</h1>
                    <div className={styles.inputGroup}>
                        <span>Update Bio: </span>
                        <input 
                            type="test"
                            placeholder="What's on your mind?"
                            value={bio}
                            onChange={(e) => setBio(e.target.value)}
                        />
                        <button onClick={updateBio} disable={loading}>
                            Update Bio
                        </button> 
                    </div>

                    <br />
                    <div className={styles.inputGroup}>
                        <span>Update Address: </span>
                        <input 
                            type="text"
                            placeholder="0x...."
                            value={linkedAddr}
                            onChange={(e) => setLinkedAddr(e.target.value)}
                        />
                        <button onClick={updateAddress} disable={loading}>
                            Update Address
                        </button>
                    </div>
                    <h1>Renew</h1>
                    <div className={styles.inputGroup}>
                        <input 
                            type="number"
                            placeholder="1"
                            value={renewFor}
                            onChange={(e) => setRenewFor(e.target.value)}
                        />
                        <span> years </span>
                        <button onClick={renew} disable={loading}>
                            Renew Domain
                        </button>
                    </div>
                    <p>Cost: {cost} FLOW</p>
                    {loading && <p>Loading....</p>}
                </div>

            </main>
        </div>
    )
}