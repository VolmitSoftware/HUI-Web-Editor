"use client";

import {
    createContext,
    type Dispatch,
    type ReactNode,
    type SetStateAction,
    useContext,
    useEffect,
    useState
} from "react";
import {type HoloUIData, type HoloUISchema} from "@/util/types";
import Ajv from "ajv";

const ajv = new Ajv();

interface ComponentHookProviderProps {

    children: ReactNode;

}

export type ComponentHookContextType = {

    data: HoloUIData | undefined;

    setData: Dispatch<SetStateAction<HoloUIData | undefined>>

    selectedComponent: string | undefined;

    setSelectedComponent: Dispatch<SetStateAction<string | undefined>>;

    validateData: (rawData: string) => string | undefined;

}

// Create a hooks for the content type
const ComponentHookContext = createContext<ComponentHookContextType | null>(null);


// Provider component for the content type
export function ComponentProvider({children}: ComponentHookProviderProps) {
    const [data, setData] = useState<HoloUIData | undefined>();
    const [selectedComponent, setSelectedComponent] = useState<string | undefined>();
    const [schema, setSchema] = useState<HoloUISchema | undefined>();

    /**
     * Downloads the schema from the schema URL.
     */
    function downloadSchema() {
        const url = 'https://raw.githubusercontent.com/Studio-Archetype/HoloUi/master/schema/holoui.schema.json';
        if (!url) {
            console.log("Schema URL not set");
            return;
        }

        console.log(`Downloading schema from ${url}`);

        fetch(url)
            .then(response => response.json())
            .then(json => {
                // Set the schema
                setSchema(json);
                // Log the success
                console.log(`Downloaded schema from ${url}`);
            })
            .catch(error => console.log(error));
    }

    /**
     * Validates the data.
     *
     * @param rawData The data to validate as a string
     */
    function validateData(rawData: string): string | undefined {
        if (!schema || !rawData) {
            return "No schema or data";
        }

        try {
            const data = JSON.parse(rawData);
            // Compile the schema
            const validate = ajv.compile(schema);

            // Validate the data
            return validate(data) ? undefined : "Invalid data";
        } catch (ignored) {
            return "Invalid JSON";
        }
    }    // Download the schema on first render

    useEffect(() => {
        downloadSchema();

        // Load data from local storage
        const storageData = localStorage.getItem("data");
        if (storageData) {
            try {
                setData(JSON.parse(storageData));
            } catch (ignored) {
            }
        } else {
            setData({
                offset: [0, 1.7, 5],
                lockPosition: false,
                followPlayer: true,
                components: [],
            });
        }
    }, []);


    useEffect(() => {
        // Make sure that the selected component is valid
        if (data && selectedComponent) {
            if (!data.components.find(component => component.id === selectedComponent)) {
                setSelectedComponent(undefined);
            }
        }

        // Save the data to local storage
        localStorage.setItem("data", JSON.stringify(data));
        console.log("Saved data to local storage")
    }, [data, setData]);

    return (
        <ComponentHookContext.Provider value={{
            data,
            setData,
            selectedComponent,
            setSelectedComponent,
            validateData
        }}>
            {children}
        </ComponentHookContext.Provider>
    );
}

// Hook for using the content type
export function useComponent(): ComponentHookContextType {
    const context = useContext(ComponentHookContext);
    if (!context) {
        throw new Error("useComponent must be used within a ComponentProvider");
    }

    return context;
}