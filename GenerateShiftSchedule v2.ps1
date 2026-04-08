<#
.AUTHOR
    Name: Graham Johnson
    Phone: <redacted>
    Email: See GitHub
.VERSION
    2.0
.VERSION_NOTE
    v2.0:
    Adds functionality to export different types of schedules (Six-Four, Panama, Four-Four, Pitman, etc.).
    Removes global parameters ($start_date, $schedule_days, $schedule, $schedule_to_export) to make safer 
    code/functionality.
    Adds functionality to specify the number of days, start date, and number of shifts per day (expects 2 
    or 3).
    v1.2:
    Corrects issue where time zone (UTC) was not correlated to local time zone for shift times. This is
    necessary as Microsoft Lists import time zones in UTC, as default.
    v1.1:
    Adds a function to export to the Microsoft List format to enable calendar view (Start DTG, End DTG).
.SYNOPSIS
    Generates a schedule that, with minor adjustments (adding names), can be imported into a Microsoft
    List for use as a calendar and scheduling application.
.DESCRIPTION
    Generates a three-shift, five crew schedule that, with limited manipulation, can be imported for
    immediate use.
.PARAMETER crews
    Represents the state of each crew, including crew designator, days on shift, current shift, and
    if the crew is currently on-shift or off-shift.
.PARAMETER start_date
    Represents the start date for the schedule (default: 1 March 2026)
.PARAMETER schedule_days
    How many days to generate the schedule for (default: 365 days)
.PARAMETER shift_rotation
    Defines the order where the shifts rotate (default: Days -> Mids -> Swings)
.PARAMETER schedule
    Helper variable used to generate the schedule to export. Has the date and the crew name for each
    shift (example: 3/1/2025, A, B, C).
.PARAMETER schedule_to_export
    Variable that stores the schedule to export, which defines start and stop DateTime objects (e.g.
    3/1/2025 6:00 AM), Crew Name, and Shift Description (i.e. "Days).

    Example: (3/1/2025 6:00 AM, 3/1/2025 2:00 PM, 'A', 'Days')
#>


<# -----------------------------------------------------------------------------------------------
START GLOBAL VARIABLE DEFIITION ------------------------------------------------------------------
------------------------------------------------------------------------------------------------#>

# The $num_crews variables are  multi-dimension arrays. For each crew, the array contains the structure:
# ('Crew Name', '# Days', 'Current Shift', 'On/Off')
# Data Types: (String, Int, String, String, String, Boolean)
# The below array is initially not set to the starting conditions

# For a four-shift crew schedule, such as Panama-12s
$four_crews = @(
    @('A', 0, 'Not Set', 0),
    @('B', 0, 'Not Set', 0),
    @('C', 0, 'Not Set', 0),
    @('D', 0, 'Not Set', 0)
    )

# For a five-shift crew schedule, such as the 6-4 Schedule
$five_crews = @(
    @('A', 0, 'Not Set', 0),
    @('B', 0, 'Not Set', 0),
    @('C', 0, 'Not Set', 0),
    @('D', 0, 'Not Set', 0),
    @('E', 0, 'Not Set', 0)
    )

# For a six-shift crew schedule, such as Panama-8s
$six_crews = @(
    @('A', 0, 'Not Set', 0),
    @('B', 0, 'Not Set', 0),
    @('C', 0, 'Not Set', 0),
    @('D', 0, 'Not Set', 0),
    @('E', 0, 'Not Set', 0),
    @('F', 0, 'Not Set', 0)
    )

# Shift Rotation 8s: Days, Mids, Swings
$shift_rotation_8s = @("Days", "Mids", "Swings")

# Shift Rotation 12s: Days, Nights
$shift_rotation_12s = @("Days", "Nights")
 
<# ------------------------------------------------------------------------------------------------
    END GLOBAL VARIABLE DEFINITION ----------------------------------------------------------------
-------------------------------------------------------------------------------------------------#>

#---------------------------------------------------------------------------------------------------------
# FUNCTION: Get-Default-Starting-Conditions --------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------

<#
.SYNOPSIS
    Provides default starting conditions, when not defined, based on shift schedule and number of crews ($case)
.DESCRIPTION
    Based on the provided case, returns default values for the $starting_days, $starting_shifts, and $starting_on_off
    variables, for use in the Set-Starting-Conditions function.
.PARAMETER case
    Type: Int
    case is determined in the Generate-Shift-Schedule function, based on the shift schedule (example: "Six-Four") and the
    number of shifts per day (example: 3). Based on case, this function provides example starting conditions.
.EXAMPLE
    $starting_days, $starting_on_off, $starting_shifts = Get-Default-Starting-Conditions 1
#>

function Get-Default-Starting-Conditions {

    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Int]$case
    )

    switch ($case) {

        # Order: starting_days, starting_on_off, starting_shifts
        # 5 Crews, 3 Shifts: Six-Four

        1 {
            # Write-Host 'Test'
            $default = @( @(4, 2, 4, 2, 6), @(1, 1, 0, 0, 1), @("Days", "Swings", "Days", "Swings", "Mids") )
            return $default
        }

        # 4 Crews, 2 Shifts: Panama 12s / Four-Four 12s / Pitman 12s

        2 {
            return @(1, 1, 1, 1), @(1, 1, 0, 0), @("Days", "Nights", "Days", "Nights")
        }

        # 6 Crews, 3 Shifts: Panama 8s / Four-Four 8s / Pitman 8s
        3 {
            return @(1, 1, 1, 1, 1, 1), @(1, 1, 1, 0, 0, 0), @("Days", "Swings", "Mids", "Days", "Swings", "Mids")
        }
    }
}

#---------------------------------------------------------------------------------------------------------
# FUNCTION: Set-Starting-Conditions ----------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------

<#
.SYNOPSIS
    Sets the starting conditions for the Parameter $crews based on the initial schedule date

.DESCRIPTION
    Takes 3x arrays, containing the number of days a crew has been on/off shift whether a crew is on
    or off shift, and a crew's current shift rotation. This function also takes optional parameters
    for start date and number of days.

.PARAMETER starting_days
    Type: Array[Int]
    The number of days each crew has been on-shift. Input as a 1 x X array
    X = num of crews

.PARAMETER starting_shifts
    Type: Array[Array[String]]
    An X x Y Array containing the starting shift for each crew (Days, Mids, Nights, or Swings). Repeats allowed
    Assumes that, if a crew is 'off', that the starting shift will be the previous shift worked (i.e.
    if D crew is off and finished Mids, the current shift will still be Mids).
    X = Number of Crews
    Y = Number of Shifts
    For the 6-4 Schedule, this is a 5 x 3 Array

.PARAMETER starting_on_off
    Type: Array[Int]
    A 1 x X Array with values 0 for off or 1 for on shift
    X = Number of Crews

.EXAMPLE
    Set-Starting-Conditions Array1[1x5] Array2[5x3] Array3[1x5] $crews

#>

function Set-Starting-Conditions {

    param(
       # starting_days: 1 x X Array containing the number of days a crew has either been on-shift or off-shift
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [array]$starting_days,

       # starting_shift: X x Y Array containing the starting shift for each crew (Days, Mids, or Swing).
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [string[]]$starting_shifts,

       # 1 x X Array with values 0 for off or 1 for on shift
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [array]$starting_on_off,

       # array to hold the crew data
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [array]$crews

    )

    # sets the starting conditions, based on the input arrays
    for ($i = 0; $i -lt $starting_on_off.Count; $i++) {
        $crews[$i][1] = $starting_days[$i]
        $crews[$i][2] = $starting_shifts[$i]
        $crews[$i][3] = $starting_on_off[$i]
    }

    Write-Output $crews

    return $crews
}

#---------------------------------------------------------------------------------------------------------
# Function Get-Next-In-Rotation --------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------

function Get-Next-In-Rotation {

    param (
        # current shift variable
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [array]$current_shift,

       # daily shifts variable - 2 or 3
       [Parameter(Mandatory)]
       [ValidateSet(2, 3)]
       [String]$daily_shifts
    )

    # 2 shifts per day - Days -> Nights
    if ($daily_shifts -eq 2) {
        if ($current_shift -eq "Days") {
            return "Nights"
        }
        else {
            return "Days"
        }
    }

    # 3 shifts per day - Days -> Mids -> Swings
    else {

        if($current_shift -eq "Days"){
            return "Mids"
        }
        elseif($current_shift -eq "Mids"){
            return "Swings"
        }
        else {
            return "Days"
        }
    }
}

#---------------------------------------------------------------------------------------------------------
# FUNCTION: Generate-Six-Four-Schedule -------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------

<#
.SYNOPSIS
    Generates a Six-Four schedule for export, based on the given starting conditions.

.DESCRIPTION
    Takes the $crews array, which is set based on the type of shift schedule and number of crews per day, and
    generates an N day (num_days) schedule, starting with the start date (s_date). The output schedule is in the 
    format (Date, Crew 1, Crew 2, Crew 3). 

.PARAMETER crews
    Type: Array
    An array that holds crew data (number and names of crews)

.PARAMETER s_date
    Type: String
    Represents the start date in string format

.PARAMETER num_days
    Type: Int
    Number of days to build the schedule for (such as 365 for 1 year)

.EXAMPLE
    Generate-Six-Four-Schedule $crews "2026-03-01" 365
#>

function Generate-Six-Four-Schedule {

    param (
       # Crews Variable
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [array]$crews,

       # Start Date
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [String]$s_date,

       # Number of Days to Schedule for
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [Int]$num_days
    )

    # Variable to hold the schedule
    $schedule = @()

    # Converts the start date to a DateTime object
    $current_date = [DateTime]$s_date

    # Generates a Schedule, By Day, in the format (Date, Crew 1, Crew 2, Crew 3)
    for ($i = 0; $i -lt $num_days; $i++) {
        
        # Converts the current date to a string
        $current_date_string = $current_date.ToString("yyy-MM-dd")

        # Current Day's Schedule Array, with placeholders for each crew
        $today_schedule = @($current_date_string, "Not Set", "Not Set", "Not Set")

        # sets each crew, based on the 6-4 shift rotation
        foreach ($crew in $crews) {

            # check to see if the crew is on-shift
            if ($crew[3] -eq 1) {

                # if the crew is on-shift, set the correct shift in the day's schedule
                if($crew[2] -eq "Days") {
                    $today_schedule[1] = $crew[0]
                }
                elseif($crew[2] -eq "Swings"){
                    $today_schedule[2] = $crew[0]
                }
                else {
                    $today_schedule[3] = $crew[0]
                }
            }

            # increment the days and check to see if the crew is going on/off-shift
            # if the crew is on-shift and days > 6, set days to 1 and shift to 0.
            # if the crew is off-shift and days >4, set days to 1, shift to 1, and adjust
            # shift according to the rotation (Days -> Mids -> Swings)

            $crew[1]++
 
            if($crew[1] -gt 6) {
                $crew[1] = 1
                $crew[3] = 0
            }

            # HELPER FUNCTION can be written for this

            # rotate the crew to the next shift in the rotation
            elseif($crew[1] -gt 4 -and $crew[3] -eq 0){
                $crew[1] = 1
                $crew[3] = 1

                $crew[2] = Get-Next-In-Rotation $crew[2] 3
            }
        }

        # Increment the day and add the row to the array

        $current_date = $current_date.AddDays(1)

        $schedule += ,$today_schedule

    }

    return $schedule

}

#---------------------------------------------------------------------------------------------------------
# Function: Get-Pitman-Offset ----------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------

<#
.SYNOPSIS
    Gets the number of days since the last Tuesday, for the Pitman schedule.

.DESCRIPTION
    Takes the start date ($offset_date) and calculates the number of days since the last Tuesday. Returns
    the pitman offset. 

.PARAMETER offset_date
    Type: DateTime
    The start date.

.EXAMPLE
    Generate-Pitman-Offset "2026-03-01" returns 5
#>

function Get-Pitman-Offset {

    param (
        # date to determine the offset for
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [DateTime]$offset_date
    )

    $offsets = @( @("Tuesday", 0), @("Wednesday", 1), 
        @("Thursday", 2), @("Friday", 3), @("Saturday", 4),
        @("Sunday", 5), @("Monday", 6) )
    
    $offset = 0

    $day_of_week = $offset_date.DayOfWeek

    # Check for all potential offsets
    for ( $i = 0; $i -lt $offsets.Count; $i++ ) {
        # check for a match
        if ( $day_of_week -eq $offsets[$i][0] ) {
            $offset = $offsets[$i][1]
            break 
        }
    }

    return $offset
}

#---------------------------------------------------------------------------------------------------------
# FUNCTION: Get-Today-Schedule ---------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------

function Get-Today-Schedule {
    
    param (
       # String for the current date
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [String]$date_string,

        # If shift "A" is on or off
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [Int]$on_off,

       # Rotation for shift "A"
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [String]$rotation,

       # 2 or 3 shifts
       [Parameter(Mandatory)]
       [ValidateSet(2, 3)]
       [Int]$daily_shifts
    )

    # define placeholder for today's schedule
    $today_schedule = @($current_date_string, "Not Set", "Not Set", "Not Set") 
        
    # Generate day 2x shift schedule
    if ( $daily_shifts -eq 2 ) {
        # Only do two shifts
        $today_schedule = @($current_date_string, "Not Set", "Not Set")
        
        # A and B are "On"
        if ( $on_off -eq 1) {
            # Check which crew is on Days
            if ( $rotation -eq "Days" ) {
                $today_schedule[1] =  "A"
                $today_schedule[2] =  "B"
            }
            else {
                $today_schedule[1] =  "B"
                $today_schedule[2] =  "A"
            }
        }
        # C and D are "On"
        else {
            if ( $rotation -eq "Days" ) {
                $today_schedule[1] =  "C"
                $today_schedule[2] =  "D"
            }
            else {
                $today_schedule[1] =  "D"
                $today_schedule[2] =  "C"
            }
        }
    }
    # Do for three shifts
    else {
        # Generate day for 3x shift schedule
        if ( $on_off -eq 1) {
            if ($rotation = "Days" ) {
                $today_schedule[1] =  "A"
                $today_schedule[2] =  "B"
                $today_schedule[3] =  "C"
            }
            elseif ($rotation = "Mids" ) {
                $today_schedule[1] =  "B"
                $today_schedule[2] =  "C"
                $today_schedule[3] =  "A"
            }
            else {
                $today_schedule[1] =  "C"
                $today_schedule[2] =  "A"
                $today_schedule[3] =  "B"
            }
        }
        else {
            if ($rotation = "Days" ) {
                $today_schedule[1] =  "D"
                $today_schedule[2] =  "E"
                $today_schedule[3] =  "F"
            }
            elseif ($rotation = "Mids" ) {
                $today_schedule[1] =  "E"
                $today_schedule[2] =  "F"
                $today_schedule[3] =  "D"
            }
            else {
                $today_schedule[1] =  "F"
                $today_schedule[2] =  "D"
                $today_schedule[3] =  "E"
            }
        }
    }

    return $today_schedule

}

#---------------------------------------------------------------------------------------------------------
# FUNCTION: Generate-Panama-Pitman-Schedule --------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------

<#
.SYNOPSIS
    Generates the a Pitman/Panama schedule for export, based on the given starting conditions.

.DESCRIPTION
    Takes the start date ($s_date), number of days ($num_days), and number of shifts per day ($daily_shifts)
    and generates a 2-2-3 schedule. If the optional parameter, $pitman, is passed then this calls the helper
    function to get the Pitman offset (days since the previous Tuesday) so that every other weekend is a three
    day weekend.
.PARAMETER s_date
    Type: String
    A string representing the start date

.PARAMETER num_days
    Type: Int
    Number of days to build the schedule for (such as 365 for 1 year)

.PARAMETER daily_shifts
    Type: Int
    Number of shifts per day (2 or 3)

.PARAMETER pitman
    Type: Bool
    Represents whether or not this is a Pitman schedule (starts on a Tuesday) or generic 2-2-3 schedule.

.EXAMPLE
    Generate-Panama-Pitman-Schedule "2026-03-01" 365 2 $true
#>

function Generate-Panama-Pitman-Schedule {

    # Note: The only difference between the Panama and Pitman is that a
    # Pitman schedule explicity starts on a Tuesday so that every other
    # weekend is a three-day weekend. Both follow the 2-2-3 pattern. 

    param (

       # Start Date
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [String]$s_date,

       # Number of Days to Schedule for
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [Int]$num_days,

       # 2 or 3 shifts per day
       [Parameter(Mandatory)]
       [ValidateSet(2, 3)]
       [Int]$daily_shifts,

       # Optional parameter to specify a pitman
       [bool]$pitman
    )

    # Variable to hold the schedule
    $schedule = @()

    # Converts the start date to a DateTime object
    $current_date = [DateTime]$s_date

    # A/B/C Shift - on, on, off, off, on, on, on, off, off, on, on, off, off, off
    # D/E/F Shift - off, off, on, on, off, off, off, on, on, off, off, on, on, on

    $shift_rotation_a_b_c = @(1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0)
    # $shift_rotation_c_d_f = @(0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1)

    # $starting_days_nights = @( @("A", "Days"), @("B", "Nights"), @("C", "Days"), @("D", "Nights") )

    $starting_days_nights = @("Days", "Nights", "Days", "Nights")

    $starting_days_swings_mids = @("Days", "Swings", "Mids", "Days", "Swings", "Mids")

    $counter = 0

    # Check for Pitman case
    if ( $pitman -eq $true ) {
        $counter = Get-Pitman-Offset $current_date

        # Write-Host "pitman offset: $counter"
    }

    # Generates a Schedule, By Day, in the format (Date, Crew 1, Crew 2, Crew 3) or (Date, Crew 1, Crew 2)
    for ($i = 0; $i -lt $num_days; $i++) {

        $current_date_string = $current_date.ToString("yyy-MM-dd")

        # define placeholder for today
        $today_schedule = ""
        
        if ( $daily_shifts -eq 2 ) {
            $on_off = $shift_rotation_a_b_c[$counter]
            $a_shift = $starting_days_nights[0]
            $today_schedule = Get-Today-Schedule $current_date_string $on_off $a_shift 2 
        }
        else {
            $on_off = $shift_rotation_a_b_c[$counter]
            $a_shift = $starting_days_swings_mids[0]
            $today_schedule = Get-Today-Schedule $current_date_string $on_off $a_shift 3
        }

        # increment counter
        $counter++

        # if $counter is 14, increment counter and swap shifts for each crew
        if ( $counter -ge 14 ) {
            $counter = 0

            # go to next shift in rotation for each shift - comment out if shifts/crews don't rotate
            if ( $daily_shifts -eq 2 ) {
                for ( $j = 0; $j -lt 4; $j++ ) {
                    $starting_days_nights[$j] = Get-Next-In-Rotation $starting_days_nights[$j] 2
                }
            }

            # Do the same for three crews
            else {
                for ( $j = 0; $j -lt $starting_days_swings_mids.Count; $j++ ) {
                    $starting_days_swings_mids[$j] = Get-Next-In-Rotation $starting_days_swings_mids[$j] 2
                }
            }
        }

        # Go to tomorrow
        $current_date = $current_date.AddDays(1)

        # Add today to the schedule
        $schedule += ,$today_schedule
    }

    return $schedule
}

#---------------------------------------------------------------------------------------------------------
# FUNCTION: Generate-Four-Four-Schedule ------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------

<#
.SYNOPSIS
    Generates a 4x on, 4x off schedule for either 4 or 6 crews, with rotation between 8-day cycles

.DESCRIPTION
    Takes the start date ($s_date), number of days ($num_days), and number of shifts per day ($daily_shifts)
    and generates a 4-4 schedule. 
.PARAMETER s_date
    Type: String
    A string representing the start date
.PARAMETER num_days
    Type: Int
    Number of days to build the schedule for (such as 365 for 1 year)
.PARAMETER daily_shifts
    Type: Int
    Number of shifts per day (2 or 3)
.EXAMPLE
    Generate-Four-Four-Schedule "2026-03-01" 365 2 $true
#>

function Generate-Four-Four-Schedule {

    param (

       # Start Date
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [String]$s_date,

       # Number of Days to Schedule for
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [String]$num_days,

       # 2 or 3 shifts per day
       [Parameter(Mandatory)]
       [ValidateSet(2, 3)]
       [String]$daily_shifts

    )

    # Variable to hold the schedule
    $schedule = @()

    # Converts the start date to a DateTime object
    $current_date = [DateTime]$s_date


    # Objects to hold days for Crew A. Other Crews can be determined by Crew A.
    $starting_shift = "Days"

    $counter = 0

    $rotation = @(1, 1, 1, 1, 0, 0, 0, 0)

    # Generates a Schedule, By Day, in the format (Date, Crew 1, Crew 2, Crew 3) or (Date, Crew 1, Crew 2)
    for ($i = 0; $i -lt $num_days; $i++) {
        
        $current_date_string = $current_date.ToString("yyy-MM-dd")

        # define placeholder for today
        $today_schedule = @($current_date_string, "Not Set", "Not Set", "Not Set")

        # gets today's schedule, based on daily_shifts
        if ( $daily_shifts -eq 2 ) {
            $on_off = $shift_rotation_a_b_c[$counter]
            $a_shift = $starting_shift
            $today_schedule = Get-Today-Schedule $current_date_string $on_off $a_shift 2 
        }
        else {
            $on_off = $shift_rotation_a_b_c[$counter]
            $a_shift = $starting_shift
            $today_schedule = Get-Today-Schedule $current_date_string $on_off $a_shift 3
        }

        # if $counter is 8, increment counter and swap shifts for each crew
        if ( $counter -ge 8 ) {
            $counter = 0

            # go to next shift in rotation for each shift - comment out if shifts/crews don't rotate
            $starting_shift = Get-Next-In-Rotation $starting_shift $daily_shifts

        }
    }

    return $schedule
}

#---------------------------------------------------------------------------------------------------------
# FUNCTION: Generate-Shift-Schedule ----------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------

<#
.SYNOPSIS
    Based on the starting conditions, creates a shift schedule and then passes it into the
    Convert-Schedule-List-Calendar for export.
.DESCRIPTION
    Note: The starting conditions are currently hard coded. V2 of this file will take terminal or
    other arguments (such as a CSV file) to generate a schedule.
.PARAMETER daily_shifts
    Type: Int
    The number of shifts per day (2 or 3)
.PARAMETER schedule_type
    Type: String
    A String representing the type of schedule. Options include: Six-Four, Panama, Four-Four, and Pitman
    Six-Four: 5x crews, 6-on, 4-off, with a rotating schedule (Days -> Mids -> Swings) - 30 day rotation
    Panama-12s: 4x crews, 2-3-2, with a rotating schedule (Days, Days, Days, Nights, Nights, Nights) - 28 day rotation
    Panama 8s: 6x crews, 2-2-3, with a rotating schedule - 42 day rotation
    Four-Four 12s: 4x Crews, 4-4, with a rotating schedule (4x Days, 4x Off, 4x Nights, 4x Off) - 16 day rotation
    Four-Four 8s: 6x Crews, 4-4, with a rotating schedule (Days, Days, Mids, Mids, Swings, Swings) - 48 day rotation
    Pitman 12s: 4x Crews in shift-pattern described here: https://www.snapschedule.com/blog/pitman-shift-pattern/
    Pitman 8s: 6x Crews is shift pattern described here: https://www.snapschedule.com/blog/pitman-shift-pattern/
.PARAMETER start_date
    Type: String
    A String representing the start date for the shift schedule. Default: "2026-03-01"
.PARAMETER schedule_days
    Type: Int
    An integer representing the number of days to build the schedule for. Default: 365
.PARAMETER starting_days
    Type: Array[Int]
    The number of days each crew has been on-shift. Input as a 1 x X array
    X = num of crews
.PARAMETER starting_shifts
    Type: Array[Array[String]]
    A X x Y Array containing the starting shift for each crew (Days, Mids, Nights, or Swings). Repeats allowed
    Assumes that, if a crew is 'off', that the starting shift will be the previous shift worked (i.e.
    if D crew is off and finished Mids, the current shift will still be Mids).
    X = Number of Crews
    Y = Number of Shifts
    For the "Six-Four" Schedule, this is a 5 x 3 Array
.PARAMETER starting_on_off
    Type: Array[Int]
    A 1 x X Array with values 0 for off or 1 for on shift
    X = Number of Crews
.EXAMPLE
    Generate-Shift-Schedule 3 "JOC" "2026-01-01"
#>

function Generate-Shift-Schedule {

    param(
       # Daily Shifts: The number of shifts for each day (2 or 3)
       [Parameter(Mandatory)]
       [ValidateSet(2, 3)]
       [Int]$daily_shifts,

       # Shift Type: Name of the type of shift (Panama, Six-Four, etc.). Validates
       # for programmed shift types
       [Parameter(Mandatory)]
       [ValidateSet("Six-Four", "Panama", "Four-Four", "Pitman")]
       [String]$shift_type,

       # Start Date: String in format "YYYY-MM-DD", default "2026-03-01"
       [String]$start_date,

       # Schedule Days: Integer for the number of days to build the schedule for
       [Int]$schedule_days,

       # starting_days: 1 x X Array containing the number of days a crew has either been on-shift or off-shift
       [array]$starting_days,

       # starting_shift: X x Y Array containing the starting shift for each crew (Days, Mids, or Swing).
       [string[]]$starting_shifts,

       # 1 x X Array with values 0 for off or 1 for on shift
       [array]$starting_on_off #,

    )

    # Local variables for number of days and start date; uses defaults if not explicitly passed into the function
    $num_days = 28
    $s_date = "2026-03-01"
    $case = 0

    # Define a local variable, $crews, which will be set to the right crew type, based on shift type and number 
    # of shifts
    $crews = @()

    # Set s_date, if defined
    if ( $PSBoundParameters.ContainsKey('start_date') ) {
        $s_date = $start_date
    }

    # Set num_days, if defined
    if ( $PSBoundParameters.ContainsKey('schedule_days') ) {
        $num_days = $schedule_days
    }

    # Case 1 - 5 Crew, 3 Shift Schedule: Six-Four Schedule
    if ($daily_shifts -eq 3 -and $shift_type -eq "Six-Four") {
        $crews = $five_crews
        $case = 1
    }

    # Case 2 - 4 Crew, 2 Shift Schedule: Panama 12s, Four-Four 12s, or Pitman 12s
    elseif ($daily_shifts -eq 2 -and ( $shift_type -eq "Panama" -or $shift_type -eq "Four-Four" -or $shift_type -eq "Pitman" ) ) {
        $crews = $four_crews
        $case = 2
    }

    # Case 3 - 6 Crew, 3 Shift Schedule:: Panama 8s, Four-Four 8s, or Pitman 8s
    elseif ($daily_shifts -eq 3 -and ( $shift_type -eq "Panama" -or $shift_type -eq "Four-Four" -or $shift_type -eq "Pitman" ) ) {
        $crews = $six_crews
        $case = 3
    }

    # Create Placeholders for starting_days, starting_on_off, starting_shifts
    $st_days, $st_on_off, $st_shifts = "", "", ""

    # checks if all starting conditions were passed. If true, set placeholder variables

    if ( $PSBoundParameters.ContainsKey('starting_days') -and $PSBoundParameters.ContainsKey('starting_on_off') -and $PSBoundParameters.ContainsKey('starting_shifts')  ) {
        $st_days, $st_on_off, $st_shifts = $starting_days, $starting_on_off, $starting_shifts
    }

    # If any starting conditions are not defined, use default starting conditions
    else {
        $st_days, $st_on_off, $st_shifts = (Get-Default-Starting-Conditions $case)
    }

    # Write-Host $st_days
    # Write-Host $st_on_off
    # Write-Host $st_shifts

    # Sets Starting Conditions for the $crews variable   
    $crews = Set-Starting-Conditions $st_days $st_shifts $st_on_off $crews

    $schedule = ""

    if ( $case -eq 1 ) {

        $schedule = Generate-Six-Four-Schedule $crews $s_date $num_days
    }

    elseif ( $case -eq 2 ) {

        if ( $schedule_type -eq "Pitman" -or $schedule_type -eq "Panama" ) {
            $pitman = $schedule_type -eq "Pitman"
            $schedule = Generate-Panama-Pitman-Schedule $s_date $num_days 2 $pitman
        }
        else {
            $schedule = Generate-Four-Four-Schedule $s_date $num_days 2
        }
    }

    elseif ( $case -eq 3 ) {
        
        if ( $schedule_type -eq "Pitman" -or $schedule_type -eq "Panama" ) {
            $pitman = $schedule_type -eq "Pitman"
            $schedule = Generate-Panama-Pitman-Schedule $s_date $num_days 3 $pitman
        }
        else {
            $schedule = Generate-Four-Four-Schedule $s_date $num_days 3
        }
    }

    # Write-Host $schedule
    return $schedule

}

#---------------------------------------------------------------------------------------------------------
# FUNCTION: Convert-Schedule-List-Calendar ---------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------

# This function transforms the simplified, 2D Array into a schedule that can be imported by
# Microsoft Lists and displayed as a calendar
# For each date, it will create 3 rows in the new array with the following format for each row
# Date, Start Time, End Time, Crew, Shift Description
# Example: "2026-03-01", "6:00 AM", "2:00 PM", "A", "Days"
 
function Convert-Schedule-List-Calendar {

    param (
       # Daily Shifts: The number of shifts for each day (2 or 3)
       [Parameter(Mandatory)]
       [ValidateSet(2, 3)]
       [Int]$daily_shifts,

        # Schedule: The schedule to convert, in format:
        # (Date, Shift 1 Value, Shift 2 Value, Shift 3 value) or same, but with 2 shifts
        # (Date, 'A', 'B', 'C') or (Date, 'A', 'B')
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [array]$schedule,

       # Time Zone ID: The time zone to use, optional
       [System.TimeZoneInfo]$time_zone_id

    )

    # Creates an object to check for the time zone
    $target_zone_id = ""

    if ( $PSBoundParameters.ContainsKey('time_zone_id') ) {
        $target_zone_id = $time_zone_id
    }

    # Default is local time for the system
    else {
        $target_zone_id = [System.TimeZoneInfo]::Local
    }

    $schedule_to_export = [PSCustomObject]@( )

    if ( $daily_shifts -eq 3 ) {

        # create a day, swing, and mid row for each day
        foreach($day in $schedule){

            # Write-Host $day[0]

            $today = $day[0]

            # unused code, since mid shift doesn't go to "tomorrow" for the list view
            # $tomorrow = $day[0].AddDays(1).ToString("MM/dd/yyyy")

            # explicity uses the target_zone_id
            $utc_zone_id = [System.TimeZoneInfo]::FindSystemTimeZoneById("UTC")

            # for each day, get the start DTG and end DTG
            $start1 = [System.TimeZoneInfo]::ConvertTime("$today 6:00 AM", $target_zone_id, $utc_zone_id).ToString('u')
            $end1 = [System.TimeZoneInfo]::ConvertTime("$today 6:30 AM", $target_zone_id, $utc_zone_id).ToString('u')
            $start2 = [System.TimeZoneInfo]::ConvertTime("$today 2:00 PM", $target_zone_id, $utc_zone_id).ToString('u')
            $end2 = [System.TimeZoneInfo]::ConvertTime("$today 2:30 PM", $target_zone_id, $utc_zone_id).ToString('u')
            $start3 = [System.TimeZoneInfo]::ConvertTime("$today 10:00 PM", $target_zone_id, $utc_zone_id).ToString('u')
            $end3 = [System.TimeZoneInfo]::ConvertTime("$today 10:30 PM", $target_zone_id, $utc_zone_id).ToString('u')

            # for each day, add the start DTG, end DTG, crew, and shift description to the array
            # Note: All times are converted to UTC and this object can be directly exported to upload
            # to a SharePoint List to enable calendar view
            # has start and stop be the same time for prettier DTGs from a calendar view.

            $schedule_to_export += [PSCustomObject]@{
                                    Start = $start1
                                    End = $end1
                                    Crew = $day[1]
                                    Desc = "Day Shift"}

            $schedule_to_export += [PSCustomObject]@{
                                    Start = $start2
                                    End = $end2
                                    Crew = $day[2]
                                    Desc = "Swing Shift"}

            $schedule_to_export += [PSCustomObject]@{
                                    Start = $start3
                                    End = $end3
                                    Crew = $day[3]
                                    Desc = "Mid Shift"}
        }
    }

 

    # otherwise, 2 shifts per day, Day and Night shifts

    else {

        # create a day and night shift row for each day
        foreach($day in $schedule){

            # Write-Output $day

            $today = $day[0]

            # explicity uses the target_zone_id
           
            $utc_zone_id = [System.TimeZoneInfo]::FindSystemTimeZoneById("UTC")
            
            $start1 = [System.TimeZoneInfo]::ConvertTime("$today 6:00 AM", $target_zone_id, $utc_zone_id).ToString('u')
            $end1 = [System.TimeZoneInfo]::ConvertTime("$today 6:30 AM", $target_zone_id, $utc_zone_id).ToString('u')
            $start2 = [System.TimeZoneInfo]::ConvertTime("$today 6:00 PM", $target_zone_id, $utc_zone_id).ToString('u')
            $end2 = [System.TimeZoneInfo]::ConvertTime("$today 6:30 PM", $target_zone_id, $utc_zone_id).ToString('u')

            # for each day, add the start DTG, end DTG, crew, and shift description to the array
            # Note: All times are converted to UTC and this object can be directly exported to upload
            # to a SharePoint List to enable calendar view

            # has start and stop be the same time for prettier DTGs from a calendar view.

            $schedule_to_export += [PSCustomObject]@{
                                    Start = $start1
                                    End = $end1
                                    Crew = $day[1]
                                    Desc = "Day Shift"}

            $schedule_to_export += [PSCustomObject]@{
                                    Start = $start2
                                    End = $end2
                                    Crew = $day[2]
                                    Desc = "Night Shift"}

        }
    }

    return $schedule_to_export
}

#---------------------------------------------------------------------------------------------------------
# FUNCTION: Export-Schedule-CSV --------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------

function Export-Schedule-CSV {

    param (
        # 
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]$schedule_to_export,
 
        # Optional parameter for export path
        [String]$path_to_export

    )

    # Prepare Schedule for Export to CSV
    $headers = @("Start Time", "End Time", "Crew", "Shift Description")
 
    # default export path
    $output_path = ".\schedule.csv"

    # use given export path, if defined
    if ( $PSBoundParameters.ContainsKey('path_to_export') ) {
        $output_path = $path_to_export
    }

    # export the schedule
    $schedule_to_export | Export-Csv -Path $output_path -NoTypeInformation -Encoding UTF8 

    # provide a message to the user that the schedule was created
    Write-Host "CSV file created at: $output_path"

}

<# ----------------------------------------------------------------------------
    TESTING -------------------------------------------------------------------
-----------------------------------------------------------------------------#>

# starting variables for testing
$daily_shifts = 3
$schedule_type = "Pitman"

# Creates an object to check for Daylight Savings Time
$target_zone_id = [System.TimeZoneInfo]::FindSystemTimeZoneById("Mountain Standard Time")

# Test

$schedule = Generate-Shift-Schedule $daily_shifts $schedule_type

# Write-Host $schedule

$schedule_to_export = Convert-Schedule-List-Calendar $daily_shifts $schedule $target_zone_id

Export-Schedule-CSV $schedule_to_export