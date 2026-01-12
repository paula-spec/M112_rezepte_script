# =====================================
# Recipe Finder & Mealplan Tool (HTML Export) - ENGLISH UI
# - Single recipe: exports its own HTML
# - Mealplan: exports ONE weekly HTML with ALL instructions (EN)
# =====================================

# Robust script path
if ($PSScriptRoot) {
    $scriptPath = $PSScriptRoot
} else {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

function Show-Menu {
    Clear-Host
    Write-Host "========== MENU =========="
    Write-Host "1 - Search by main ingredient"
    Write-Host "2 - Search by category"
    Write-Host "3 - Search by area (country)"
    Write-Host "4 - Create meal plan (1 weekly HTML)"
    Write-Host "5 - Exit"
    Write-Host "=========================="
    Write-Host ""
}

function HtmlEncode([string]$s) {
    if ($null -eq $s) { return "" }
    return ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' -replace "'","&#39;")
}

function Get-MealDetails($id) {
    $url = "https://www.themealdb.com/api/json/v1/1/lookup.php?i=$id"
    try {
        return Invoke-RestMethod -Uri $url -ErrorAction Stop
    } catch {
        Write-Host "Error: API not reachable."
        return $null
    }
}

function Build-IngredientsHtml($meal) {
    $items = @()
    foreach ($i in 1..20) {
        $ing = $meal."strIngredient$i"
        $mea = $meal."strMeasure$i"
        if ($ing -and $ing.Trim().Length -gt 0) {
            $items += "<li>$(HtmlEncode $ing) ($(HtmlEncode $mea))</li>"
        }
    }
    return ($items -join "`n")
}

# ===========================================================
# Single recipe export: HTML file
# ===========================================================
function Save-Recipe($meal) {

    $safeName = ($meal.strMeal -replace '[^a-zA-Z0-9_.-]', '_')
    $filename = Join-Path -Path $scriptPath -ChildPath ("Recipe_{0}.html" -f $safeName)

    $title = HtmlEncode $meal.strMeal
    $cat   = HtmlEncode $meal.strCategory
    $area  = HtmlEncode $meal.strArea
    $img   = HtmlEncode $meal.strMealThumb

    $ingredientsHtml = Build-IngredientsHtml $meal

    # Instructions: EN (TheMealDB uses strInstructions as English by default)
    $instructionsEN = HtmlEncode $meal.strInstructions
    $instructionsEN = $instructionsEN -replace "`r`n","<br>" -replace "`n","<br>"

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>$title</title>
<style>
  body { font-family: Arial, sans-serif; margin: 30px; background:#f6f6f6; }
  .card { background:#fff; padding: 18px; border-radius: 12px; box-shadow:0 2px 12px rgba(0,0,0,.08); max-width: 900px; margin: 0 auto; }
  h1 { margin-top:0; }
  .meta { color:#444; margin-bottom: 10px; }
  img { width: 320px; max-width: 100%; border-radius: 10px; margin: 12px 0; }
  h2 { margin-bottom: 8px; }
  ul { padding-left: 18px; }
  .p { line-height:1.45; }
</style>
</head>
<body>
  <div class="card">
    <h1>$title</h1>
    <div class="meta"><b>Category:</b> $cat<br><b>Area:</b> $area</div>
    <img src="$img" alt="Recipe image">
    <h2>Ingredients</h2>
    <ul>
      $ingredientsHtml
    </ul>
    <h2>Instructions (EN)</h2>
    <div class="p">$instructionsEN</div>
  </div>
</body>
</html>
"@

    Set-Content -Path $filename -Value $html -Encoding UTF8
    Write-Host "`nSaved HTML to:`n$filename`n"
}

# ===========================================================
# Choose a recipe from a list
#  -NoExport: prevents single HTML export (important for mealplan)
#  -ReturnMeal: returns Meal object
# ===========================================================
function Choose-Meal {
    param(
        [Parameter(Mandatory=$true)] $meals,
        [switch]$NoExport,
        [switch]$ReturnMeal
    )

    for ($i = 0; $i -lt $meals.Count; $i++) {
        Write-Host "$($i+1). $($meals[$i].strMeal)"
    }

    $choice = Read-Host "`nSelect recipe number"
    $index = [int]$choice - 1

    if ($index -ge 0 -and $index -lt $meals.Count) {
        $details = Get-MealDetails $meals[$index].idMeal
        if ($null -eq $details -or $null -eq $details.meals) { return $null }

        $meal = $details.meals[0]

        Write-Host "`n--- RECIPE ---"
        Write-Host "Name:      $($meal.strMeal)"
        Write-Host "Category:  $($meal.strCategory)"
        Write-Host "Area:      $($meal.strArea)"
        Write-Host "`nInstructions (EN):`n$($meal.strInstructions)"

        if (-not $NoExport) {
            Save-Recipe $meal
        }

        if ($ReturnMeal) { return $meal }
        return $null
    } else {
        Write-Host "Invalid selection!"
        return $null
    }
}

function Search-ByIngredient {
    $ingredient = Read-Host "`nEnter main ingredient"
    $url = "https://www.themealdb.com/api/json/v1/1/filter.php?i=$ingredient"
    try {
        $response = Invoke-RestMethod -Uri $url -ErrorAction Stop
    } catch {
        Write-Host "Error: API not reachable."
        return
    }

    if ($response.meals) {
        Choose-Meal -meals $response.meals
    } else {
        Write-Host "No recipes found."
    }
}

function Search-ByCategory {
    param([switch]$ReturnMeal)

    Write-Host "`nAvailable categories:"
    try {
        $categories = Invoke-RestMethod -Uri "https://www.themealdb.com/api/json/v1/1/list.php?c=list" -ErrorAction Stop
    } catch {
        Write-Host "Error: API not reachable."
        return $null
    }

    $categories.meals | ForEach-Object { Write-Host "- " $_.strCategory }

    $cat = Read-Host "`nEnter category"
    $url = "https://www.themealdb.com/api/json/v1/1/filter.php?c=$cat"
    try {
        $response = Invoke-RestMethod -Uri $url -ErrorAction Stop
    } catch {
        Write-Host "Error: API not reachable."
        return $null
    }

    if ($response.meals) {
        if ($ReturnMeal) {
            return Choose-Meal -meals $response.meals -NoExport -ReturnMeal
        } else {
            Choose-Meal -meals $response.meals
            return $null
        }
    } else {
        Write-Host "No results."
        return $null
    }
}

function Search-ByArea {
    Write-Host "`nAvailable areas:"
    try {
        $areas = Invoke-RestMethod -Uri "https://www.themealdb.com/api/json/v1/1/list.php?a=list" -ErrorAction Stop
    } catch {
        Write-Host "Error: API not reachable."
        return
    }

    $areas.meals | ForEach-Object { Write-Host "- " $_.strArea }

    $area = Read-Host "`nEnter area/country"
    $url = "https://www.themealdb.com/api/json/v1/1/filter.php?a=$area"
    try {
        $response = Invoke-RestMethod -Uri $url -ErrorAction Stop
    } catch {
        Write-Host "Error: API not reachable."
        return
    }

    if ($response.meals) {
        Choose-Meal -meals $response.meals
    } else {
        Write-Host "No recipes found."
    }
}

# ===========================================================
# Mealplan export: ONE weekly HTML with ALL instructions (EN)
# ===========================================================
function Export-MealPlanHtml {
    param(
        [Parameter(Mandatory=$true)] $MealPlan
    )

    $file = Join-Path -Path $scriptPath -ChildPath "Mealplan_Week.html"

    $css = @"
<style>
  body { font-family: Arial, sans-serif; margin: 30px; background:#f6f6f6; }
  h1 { text-align:center; margin-bottom: 18px; }
  .grid { display:grid; grid-template-columns: repeat(7, 1fr); gap: 14px; }
  .day { background:#fff; border-radius:12px; padding:12px; box-shadow:0 2px 10px rgba(0,0,0,.08); }
  .day h2 { font-size:16px; margin:0 0 8px 0; text-align:center; }
  .mealTitle { font-weight:700; margin:8px 0; text-align:center; }
  .meta { font-size: 12px; color:#444; margin-bottom:8px; }
  img { width:100%; border-radius:10px; margin:8px 0; }
  details { margin-top:8px; }
  summary { cursor:pointer; font-weight:600; }
  ul { padding-left: 18px; margin: 6px 0; }
  .p { font-size: 13px; line-height: 1.35; }
  .small { font-size: 12px; color:#666; text-align:center; }
</style>
"@

    $html = "<!DOCTYPE html><html lang='en'><head><meta charset='UTF-8'><title>Mealplan</title>$css</head><body>"
    $html += "<h1>Meal Plan - Week</h1>"
    $html += "<div class='grid'>"

    foreach ($entry in $MealPlan) {
        $day  = HtmlEncode $entry.Day
        $meal = $entry.Meal

        if ($null -eq $meal) {
            $html += "<div class='day'><h2>$day</h2><div class='small'>No meal selected</div></div>"
            continue
        }

        $title = HtmlEncode $meal.strMeal
        $cat   = HtmlEncode $meal.strCategory
        $area  = HtmlEncode $meal.strArea
        $img   = HtmlEncode $meal.strMealThumb

        $ingredientsHtml = Build-IngredientsHtml $meal

        $instructionsEN = HtmlEncode $meal.strInstructions
        $instructionsEN = $instructionsEN -replace "`r`n","<br>" -replace "`n","<br>"

        $html += "<div class='day'>"
        $html += "<h2>$day</h2>"
        $html += "<div class='mealTitle'>$title</div>"
        $html += "<div class='meta'>Category: $cat<br>Area: $area</div>"
        if ($img) { $html += "<img src='$img' alt='Recipe image'>" }

        $html += "<details><summary>Ingredients</summary><ul>$ingredientsHtml</ul></details>"
        $html += "<details open><summary>Instructions (EN)</summary><div class='p'>$instructionsEN</div></details>"
        $html += "</div>"
    }

    $html += "</div></body></html>"

    Set-Content -Path $file -Value $html -Encoding UTF8
    Write-Host "`nSaved weekly meal plan to:`n$file`n"
}

# ===========================================================
# Create mealplan: NO single exports, at end ONE HTML
# ===========================================================
function Create-MealPlan {

    $weekDays = @("Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday")

    Write-Host "`nHow many meals for the plan? (max. 7)"
    $numMeals = [int](Read-Host)

    if ($numMeals -lt 1 -or $numMeals -gt 7) {
        Write-Host "Please enter a number from 1 to 7."
        return
    }

    $plan = @()

    for ($i = 0; $i -lt 7; $i++) {
        $day = $weekDays[$i]

        if ($i -lt $numMeals) {
            Write-Host ("`nSelect meal for {0}:" -f $day)
            $meal = Search-ByCategory -ReturnMeal  # ReturnMeal => NO single export
            $plan += [PSCustomObject]@{ Day = $day; Meal = $meal }
        } else {
            $plan += [PSCustomObject]@{ Day = $day; Meal = $null }
        }
    }

    Export-MealPlanHtml -MealPlan $plan
    Write-Host "`nMeal plan completed!"
}

# =======================
# MAIN PROGRAM
# =======================
do {
    Show-Menu
    $selection = Read-Host "Choose option (1-5): "

    switch ($selection) {
        "1" { Search-ByIngredient }
        "2" { Search-ByCategory }
        "3" { Search-ByArea }
        "4" { Create-MealPlan }
        "5" { Write-Host "Exiting..."; break }
        default { Write-Host "Invalid input!" }
    }

    Read-Host "Press Enter to continue"
}
while ($true)
