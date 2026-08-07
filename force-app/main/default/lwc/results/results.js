import { LightningElement, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import getWeeklyResults from "@salesforce/apex/ResultsService.getWeeklyResults";
import getSeasonalResults from "@salesforce/apex/ResultsService.getSeasonalResults";
import getWeekNumbers from "@salesforce/apex/SettingsService.getWeekNumbers";
import getSettings from "@salesforce/apex/SettingsService.getSettings";

const REFRESH_INTERVAL_MS = 120000;
const PERCENT_MAX = 1;

export default class Results extends LightningElement {
  weekNumber;
  currentWeek;
  allWeekNumbers = [];
  lastRefreshed;

  weeklyResult;
  seasonalResult;

  refreshTimerId;

  @wire(getSettings)
  wiredSettings({ data }) {
    if (data && data.CurrentWeek__c != null) {
      this.currentWeek = data.CurrentWeek__c;
      if (!this.weekNumber) {
        this.weekNumber = String(data.CurrentWeek__c);
      }
    }
  }

  @wire(getWeekNumbers)
  wiredWeekNumbers({ data, error }) {
    if (data) {
      this.allWeekNumbers = data;
    } else if (error) {
      this.allWeekNumbers = [];
    }
  }

  @wire(getWeeklyResults, { week: "$weekNumber" })
  wiredWeekly(result) {
    this.weeklyResult = result;
  }

  @wire(getSeasonalResults)
  wiredSeasonal(result) {
    this.seasonalResult = result;
  }

  // Lightning App Page tabs can stay mounted in the background when the user
  // navigates away, so connectedCallback/@wire won't naturally re-fire on
  // return. CurrentPageReference does fire on tab (re)activation, so use it
  // to force a refetch and avoid showing stale data from a previous visit.
  @wire(CurrentPageReference)
  handleCurrentPageReference(pageReference) {
    if (pageReference) {
      this.refreshAll();
    }
  }

  connectedCallback() {
    // Intentional polling to auto-refresh results every 2 minutes (matches
    // the old VF page's setTimeout behavior); cleared in disconnectedCallback.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.refreshTimerId = setInterval(() => this.refreshAll(), REFRESH_INTERVAL_MS);
  }

  disconnectedCallback() {
    if (this.refreshTimerId) {
      clearInterval(this.refreshTimerId);
      this.refreshTimerId = undefined;
    }
  }

  refreshAll() {
    if (this.weeklyResult) {
      refreshApex(this.weeklyResult);
    }
    if (this.seasonalResult) {
      refreshApex(this.seasonalResult);
    }
    this.lastRefreshed = new Date();
  }

  handleWeekChange(event) {
    this.weekNumber = event.detail.value;
  }

  get weekOptions() {
    const cap = this.currentWeek || 1;
    return (this.allWeekNumbers || [])
      .filter((week) => Number(week) <= cap)
      .map((week) => ({ label: `Week ${week}`, value: week }));
  }

  get showWeekPicker() {
    return (this.currentWeek || 0) > 1;
  }

  get lastRefreshedLabel() {
    return this.lastRefreshed ? this.lastRefreshed.toLocaleString() : "";
  }

  get percentMax() {
    return PERCENT_MAX;
  }

  get isWeeklyLoading() {
    return !this.weeklyResult;
  }

  get weeklyLoadError() {
    return this.weeklyResult && this.weeklyResult.error
      ? this.reduceError(this.weeklyResult.error)
      : undefined;
  }

  get weeklyData() {
    return this.weeklyResult && this.weeklyResult.data
      ? this.weeklyResult.data
      : undefined;
  }

  get weeklyHasResults() {
    return !!(
      this.weeklyData &&
      this.weeklyData.pointsAvailable &&
      this.weeklyData.resultRows &&
      this.weeklyData.resultRows.length > 0
    );
  }

  get weeklyPointsAvailable() {
    return this.weeklyData ? this.weeklyData.pointsAvailable : 0;
  }

  get weeklyPointsRows() {
    return this.weeklyData
      ? this.weeklyData.resultRows.map((r) => ({
          label: r.nickname,
          value: r.pointsScored
        }))
      : [];
  }

  get weeklyPercentRows() {
    return this.weeklyData
      ? this.weeklyData.resultRows.map((r) => ({
          label: r.nickname,
          value: r.winPercentage
        }))
      : [];
  }

  get weeklyPointsTitle() {
    return `Points Scored - Week ${this.weekNumber || ""}`;
  }

  get weeklyPercentTitle() {
    return `Win Percentage - Week ${this.weekNumber || ""}`;
  }

  get isSeasonalLoading() {
    return !this.seasonalResult;
  }

  get seasonalLoadError() {
    return this.seasonalResult && this.seasonalResult.error
      ? this.reduceError(this.seasonalResult.error)
      : undefined;
  }

  get seasonalData() {
    return this.seasonalResult && this.seasonalResult.data
      ? this.seasonalResult.data
      : undefined;
  }

  get seasonalHasResults() {
    return !!(
      this.seasonalData &&
      this.seasonalData.pointsAvailable &&
      this.seasonalData.resultRows &&
      this.seasonalData.resultRows.length > 0
    );
  }

  get seasonalPointsAvailable() {
    return this.seasonalData ? this.seasonalData.pointsAvailable : 0;
  }

  get seasonalPointsRows() {
    return this.seasonalData
      ? this.seasonalData.resultRows.map((r) => ({
          label: r.nickname,
          value: r.pointsScored
        }))
      : [];
  }

  get seasonalPercentRows() {
    return this.seasonalData
      ? this.seasonalData.resultRows.map((r) => ({
          label: r.nickname,
          value: r.winPercentage
        }))
      : [];
  }

  reduceError(error) {
    if (error && error.body && error.body.message) {
      return error.body.message;
    }
    if (error && error.message) {
      return error.message;
    }
    return "An unknown error occurred while loading results.";
  }
}