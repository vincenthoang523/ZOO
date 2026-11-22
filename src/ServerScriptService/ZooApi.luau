-- ZooApi: how other server scripts (ZooRace) reach player data owned by ZooServer. ZooServer fills in the functions
-- when it starts: session, findAnimal, rate, giveCash, addLuck, addMoney, notify, changed,
-- addAnimal, isAdmin, wipe; ZooWeather adds startWeather, clearWeather, setWeatherPaused, weatherPaused. Server only (ServerScriptService).
return {}
