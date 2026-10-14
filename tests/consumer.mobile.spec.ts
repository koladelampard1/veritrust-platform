import {test,expect,devices} from '@playwright/test';
const base=process.env.VERITRUST_BASE_URL||'https://veritrust-platform.vercel.app';
test.use({...devices['Pixel 7']});
test('consumer page and examples work on mobile',async({page})=>{
 await page.goto(base+'/consumer',{waitUntil:'domcontentloaded'});
 await expect(page.getByRole('heading',{name:'Know what you’re holding.'})).toBeVisible();
 await page.getByRole('button',{name:'Enrolled record'}).click();
 await expect(page.getByRole('heading',{name:'Digital record matched'})).toBeVisible();
 await expect(page.getByText(/does not establish the identity, quality/)).toBeVisible();
 await page.getByRole('button',{name:'Unknown identifier'}).click();
 await expect(page.getByRole('heading',{name:'Unable to authenticate'})).toBeVisible();
});
test('public API returns an appropriately qualified response for an unknown synthetic code',async({page})=>{
 await page.goto(base+'/consumer',{waitUntil:'domcontentloaded'});
 await page.locator('#cv-code').fill('UNKNOWN-SYNTHETIC-TOKEN-1234567890');
 await page.getByRole('button',{name:'Verify product'}).click();
 await expect(page.locator('.cv-result')).toBeVisible({timeout:20000});
 const heading=await page.locator('.cv-result h2').innerText();
 expect(['Unable to authenticate','Verification temporarily unavailable']).toContain(heading);
});
test('safety reporting requires a description',async({page})=>{
 await page.goto(base+'/consumer',{waitUntil:'domcontentloaded'});
 await page.getByRole('button',{name:'Report suspicious product →'}).click();
 await expect(page.locator('#cv-details')).toBeVisible();
 await expect(page.getByRole('button',{name:'Preview report'})).toBeDisabled();
 await page.locator('#cv-details').fill('Potentially altered synthetic demo label');
 await expect(page.getByRole('button',{name:'Preview report'})).toBeEnabled();
 // Do not submit during CI to avoid creating persistent safety reports.
});
