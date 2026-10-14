import {defineConfig} from '@playwright/test';
export default defineConfig({testDir:'./tests',timeout:30000,retries:1,reporter:'list',use:{headless:true,trace:'retain-on-failure'},projects:[{name:'chromium',use:{browserName:'chromium'}}]});
