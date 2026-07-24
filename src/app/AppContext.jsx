import { createContext, useContext } from "react";

export const DEFAULT_DATA = { settings: {}, weight: [], history: {}, sessions: {}, diet: {}, water: {}, activity: {}, photos: [], plan: null };
export const AppCtx = createContext(null);
export const useApp = () => useContext(AppCtx);
