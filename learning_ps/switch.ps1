$House = Read-Host -Prompt "What is your game of thrones family?"

Switch($House.ToLower()) {
    "targaryen" {
        write-host "You're crazy!"; break
    }
    "stark" {
        write-host "Nothing bad is going to happen at the wall!"; break
    }
    "lannister" {
        write-host "You always pay your debts!"; break
    }
}