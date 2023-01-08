/*
Covid 19 Data Exploration 
Data is taken from here: https://ourworldindata.org/covid-deaths
Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types
The data file is split into two parts, one of them contains info about deaths and another - about vaccinations.
This is done to use joins 
*/


select *
from Portfolio..CovidDeaths
where continent is not null
order by 3,4

--select *
--from Portfolio..Vaccinations
--order by 3,4

--Select some Data from Covid Deaths
--where continent is not null excludes data with the missing continents value because it has locations like World, Africa etc.

select location, date, total_cases, new_cases, total_deaths, population
from Portfolio..CovidDeaths
where continent is not null
order by 1,2

--Looking at Total Cases vs Total Deaths.
--The DeathPercentatge column shows the probability of dying if you contracted Covid in your country

select location, date, total_cases, new_cases, (total_deaths/total_cases)*100 as DeathPercentage
from Portfolio..CovidDeaths
--where location like '%states%'
where location like '%germany%'
order by 1,2

--Looking at Total Cases vs Population
select location, date, total_cases, new_cases, (total_cases/population)*100 as PercentPopulationInfected
from Portfolio..CovidDeaths
where location like '%germany%'
order by 1,2

--Looking at Countries with Highest Infection Rate compared to Population
select location, Population, MAX(total_cases) as HighestInfectionCount, Max((total_cases/population))*100 as PercentPopulationInfected
from Portfolio..CovidDeaths
--where location like '%germany%'
where continent is not null
Group by Location, Population
order by PercentPopulationInfected desc

--Looking at Countries with Highest Death Count per Population
select location, MAX(cast(total_deaths as int)) as TotalDeathCount, Max((total_cases/population))*100 as PercentPopulationInfected
from Portfolio..CovidDeaths
--where location like '%germany%'
where continent is not null
Group by Location
order by TotalDeathCount desc

--Group by continents
select continent, MAX(cast(total_deaths as int)) as TotalDeathCount
from Portfolio..CovidDeaths
where continent is not null
Group by continent
order by TotalDeathCount desc

--Group by location where contient is null
select location, MAX(cast(total_deaths as int)) as TotalDeathCount
from Portfolio..CovidDeaths
where continent is null
Group by location
order by TotalDeathCount desc

--Showing the continents with the highest death count per population
select continent, MAX(cast(total_deaths as int)) as TotalDeathCount
from Portfolio..CovidDeaths
where continent is not null
Group by continent
order by TotalDeathCount desc

--GLOBAL NUMBERS
select location, date, SUM(new_cases) as New_Cases_Sum, SUM(total_cases) as Total_Cases_Sum, SUM(cast(new_deaths as int)) as Total_Deaths, (SUM(cast(new_deaths as int))/SUM(new_cases))*100 as NewDeathsTONewCases,
(SUM(cast(new_deaths as int))/SUM(total_cases))*100 as NewDeathsTOTotalCases
from Portfolio..CovidDeaths
where date is not null
Group by location, date
order by 1,2

--SUM of new cases vs. total cases. To check if total cases + new cases = total_cases next day 
select location, date, total_cases, new_cases, total_cases + new_cases as total_casesPLUSnew_cases --, SUM(new_cases) as New_Cases_Sum, SUM(cast(new_deaths as int)) as Total_Deaths, (SUM(cast(new_deaths as int))/SUM(new_cases))*100 as DeathPercentage
from Portfolio..CovidDeaths
where continent is not null
--Group by date
order by 1,2

SET LANGUAGE ENGLISH

--Join Deaths and Vaccinations tables

select *
from Portfolio..CovidDeaths dea
join Portfolio..Vaccinations vac
	on dea.location = vac.location
	and dea.date = vac.date


--Looking at Total Population vs. Vaccinations

select dea.continent, dea.location, dea.population, vac.new_vaccinations
from Portfolio..CovidDeaths dea
join Portfolio..Vaccinations vac
	on dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null
order by 2,3

--Incorrect query
--Looking at Total Population vs. Vaccinations with partition by location
--This is incorrect query because the TotalVaxRolling (Total vaccinations number for the current date) 
--number does not change with the date.
--To correct this, partition needs to be ordered by location and date (see next query)

select dea.continent, dea.location, dea.population, vac.new_vaccinations
, SUM (CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location) as TotalVaxRolling
from Portfolio..CovidDeaths dea
join Portfolio..Vaccinations vac
	on dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null
order by 2,3

--Correct query
--Looking at Total Population vs. Vaccinations with partition by location
--Partition order by location and date
select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM (CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location order by dea.location,
dea.date) as TotalVaxRolling
from Portfolio..CovidDeaths dea
join Portfolio..Vaccinations vac
	on dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null
order by 2,3

--Use CTE
with PopvsVac (continent, location, date, population, new_vaccinations, TotalVaxRolling)
as
(
select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM (CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location order by dea.location,
dea.date)
from Portfolio..CovidDeaths dea
join Portfolio..Vaccinations vac
	on dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null
--order by 2,3. If this is uncommented, error appears
)
select *, (TotalVaxRolling/population)*100
from PopvsVac
--SET LANGUAGE ENGLISH

--Temp Table
DROP table if exists #PercentPopulationVaccinated
create table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
new_vaccinations numeric,
TotalVaxRolling numeric,
)


insert into #PercentPopulationVaccinated
select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM (CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location order by dea.location,
dea.date) as TotalVaxRolling
from Portfolio..CovidDeaths dea
join Portfolio..Vaccinations vac
	on dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null
order by 2,3


select *, (TotalVaxRolling/population)*100 as TotalVaxRollingToPopulation
from #PercentPopulationVaccinated

-- Creating View to store data for later visualizations
Create View PercentPopulationVaccinated as
select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM (CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location order by dea.location,
dea.date) as TotalVaxRolling
from Portfolio..CovidDeaths dea
join Portfolio..Vaccinations vac
	on dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null
--order by 2,3

select * from PercentPopulationVaccinated
