SELECT *
FROM covid_deaths;

SELECT *
FROM covid_vaccinations;

-- Updating data types

UPDATE covid_deaths
set `date` = str_to_date(`date`, '%m/%d/%Y');

UPDATE covid_vaccinations
set `date` = str_to_date(`date`, '%m/%d/%Y');

ALTER TABLE covid_vaccinations
MODIFY COLUMN `date` date;

UPDATE covid_vaccinations_staging
SET new_vaccinations = NULL
WHERE new_vaccinations = '';

ALTER TABLE covid_vaccinations_staging
MODIFY COLUMN `new_vaccinations` bigint;

UPDATE covid_vaccinations_staging
SET new_vaccinations = NULL
WHERE new_vaccinations = '';

-- Simple calculations such as death percentage, population percentage, infection rate

SELECT country, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
FROM covid_deaths
WHERE continent != '', country LIKE '%states';

SELECT country, date, total_cases, total_deaths, population, (total_cases/population)*100 as PopulationCaseRate
FROM covid_deaths
WHERE continent != '', country = 'United States'
ORDER by PopulationCaseRate DESC;

SELECT country, population, MAX(total_cases) as HighestInfectionCount, MAX((total_cases/population)) * 100 as InfectionRate
FROM covid_deaths
WHERE continent != ''
GROUP BY country, population
ORDER BY InfectionRate DESC;

SELECT country, total_deaths
FROM covid_deaths
WHERE 'total_deaths' = ""
;


-- Duplicate/Staging Table

CREATE TABLE covid_deaths_staging
LIKE covid_deaths;

INSERT covid_deaths_staging
SELECT *
FROM covid_deaths;

SELECT *
FROM covid_deaths_staging;

CREATE TABLE covid_vaccinations_staging
LIKE covid_vaccinations;

INSERT covid_vaccinations_staging
SELECT *
FROM covid_vaccinations;

SELECT *
FROM covid_vaccinations_staging;

UPDATE covid_deaths_staging
SET total_deaths = NULL
WHERE total_deaths = '';

ALTER TABLE covid_deaths_staging
MODIFY COLUMN `total_deaths` bigint;


-- Continent Grouping

SELECT country, MAX(total_deaths) as DeathCount
FROM covid_deaths_staging
WHERE continent = '' AND total_deaths IS NOT NULL AND country NOT LIKE '%income%'
GROUP BY country
ORDER BY DeathCount DESC;


-- Global Numbers

SELECT date, SUM(new_cases), SUM(new_deaths), SUM(new_deaths)/SUM(new_cases)*100 as DeathPercentage
FROM covid_deaths_staging
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY 1,2;


-- Total Population vs Vaccinations

SELECT dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations) OVER (PARTITION BY dea.country ORDER BY dea.country, dea.date) as vac_rolling
FROM covid_deaths_staging dea
JOIN covid_vaccinations vac
	ON dea.country = vac.country
    AND dea.date = vac.date
WHERE dea.continent != ''
ORDER BY 2,3;


-- Create CTE to use newly created column

WITH PopvsVac (continent, country, date, population, new_vaccinations, vac_rolling)
AS
(
SELECT dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations) OVER (PARTITION BY dea.country ORDER BY dea.country, dea.date) as vac_rolling
FROM covid_deaths_staging dea
JOIN covid_vaccinations_staging vac
	ON dea.country = vac.country
    AND dea.date = vac.date
WHERE dea.continent != ''
)
SELECT *, (vac_rolling/population)*100
FROM PopvsVac;


-- Temp Table

DROP TABLE IF EXISTS PercentPopulationVaccinated;
CREATE TEMPORARY TABLE PercentPopulationVaccinated
(
Continent text,
country text,
date datetime,
population text,
new_vaccinations bigint,
vac_rolling text
);

INSERT INTO PercentPopulationVaccinated
SELECT dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations) OVER (PARTITION BY dea.country ORDER BY dea.country, dea.date) as vac_rolling
FROM covid_deaths_staging dea
JOIN covid_vaccinations_staging vac
	ON dea.country = vac.country
    AND dea.date = vac.date
WHERE dea.continent != '';

SELECT *, (vac_rolling/population)*100
FROM PercentPopulationVaccinated;


-- Creating Views for Data Visualization

CREATE VIEW PercentPopulationVaccinated AS
SELECT dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations) OVER (PARTITION BY dea.country ORDER BY dea.country, dea.date) as vac_rolling
FROM covid_deaths_staging dea
JOIN covid_vaccinations_staging vac
	ON dea.country = vac.country
    AND dea.date = vac.date
WHERE dea.continent != '';

