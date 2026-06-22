using System.Text.Json.Serialization;

namespace Querator;
public class QueratorEvent
{
    public QueratorEvent(string eventName)
    {
        EventName = eventName;
    }

    [JsonPropertyName("event")]
    public string EventName { get; }
}

public class QueratorMatchEvent : QueratorEvent
{
    [JsonPropertyName("matchid")]
    public required long MatchId { get; init; }

    protected QueratorMatchEvent(string eventName) : base(eventName)
    {
    }
}

public class QueratorMatchTeamEvent : QueratorMatchEvent
{
    [JsonPropertyName("team")]
    public required string Team { get; init; }

    protected QueratorMatchTeamEvent(string eventName) : base(eventName)
    {
    }
}

public class QueratorMapEvent : QueratorMatchEvent
{
    [JsonPropertyName("map_number")]
    public required int MapNumber { get; init; }

    protected QueratorMapEvent(string eventName) : base(eventName)
    {
    }
}

public class QueratorMapTeamEvent : QueratorMapEvent
{
    [JsonPropertyName("team_int")]
    public required int TeamNumber { get; init; }

    protected QueratorMapTeamEvent(string eventName) : base(eventName)
    {
    }
}

public class QueratorRoundEvent : QueratorMapEvent
{
    [JsonPropertyName("round_number")]
    public required int RoundNumber { get; init; }

    protected QueratorRoundEvent(string eventName) : base(eventName)
    {
    }
}

public class QueratorTimedRoundEvent : QueratorRoundEvent
{
    [JsonPropertyName("round_time")]
    public required int RoundTime { get; init; }

    protected QueratorTimedRoundEvent(string eventName) : base(eventName)
    {
    }
}

public class QueratorPlayerRoundEvent : QueratorRoundEvent
{

    [JsonPropertyName("player")]
    public required int Player { get; init; }

    protected QueratorPlayerRoundEvent(string eventName) : base(eventName)
    {
    }
}

public class QueratorPlayerTimedRoundEvent : QueratorTimedRoundEvent
{
    [JsonPropertyName("player")]
    public required int Player { get; init; }

    protected QueratorPlayerTimedRoundEvent(string eventName) : base(eventName)
    {
    }
}

public class QueratorPlayerDisconnectedEvent : QueratorMatchEvent
{
    [JsonPropertyName("player")]
    public required int Player { get; init; }

    public QueratorPlayerDisconnectedEvent() : base("player_disconnect")
    {
    }
}

public class QueratorSeriesStartedEvent : QueratorMatchEvent
{
    [JsonPropertyName("team1")]
    public required QueratorTeamWrapper Team1 { get; init; }

    [JsonPropertyName("team2")]
    public required QueratorTeamWrapper Team2 { get; init; }

    [JsonPropertyName("num_maps")]
    public required int NumberOfMaps { get; init; }

    public QueratorSeriesStartedEvent() : base("series_start")
    {
    }
}

public class QueratorSeriesResultEvent : QueratorMatchEvent
{
    [JsonPropertyName("time_until_restore")]
    public required int TimeUntilRestore { get; init; }

    [JsonPropertyName("winner")]
    public required Winner Winner { get; init; }

    [JsonPropertyName("team1_series_score")]
    public required int Team1SeriesScore { get; init; }

    [JsonPropertyName("team2_series_score")]
    public required int Team2SeriesScore { get; init; }

    public QueratorSeriesResultEvent() : base("series_end")
    {
    }
}

public class GoingLiveEvent : QueratorMapEvent
{
    public GoingLiveEvent() : base("going_live")
    {
    }
}

public class QueratorRoundEndedEvent : QueratorTimedRoundEvent
{

    [JsonPropertyName("reason")]
    public required int Reason { get; init; }

    [JsonPropertyName("winner")]
    public required Winner Winner { get; init; }

    [JsonPropertyName("team1")]
    public required QueratorStatsTeam StatsTeam1 { get; init; }

    [JsonPropertyName("team2")]
    public required QueratorStatsTeam StatsTeam2 { get; init; }

    public QueratorRoundEndedEvent() : base("round_end")
    {
    }
}

public class MapResultEvent : QueratorMapEvent
{
    [JsonPropertyName("winner")]
    public required Winner Winner { get; init; }

    [JsonPropertyName("team1")]
    public required QueratorStatsTeam StatsTeam1 { get; init; }

    [JsonPropertyName("team2")]
    public required QueratorStatsTeam StatsTeam2 { get; init; }

    public MapResultEvent() : base("map_result")
    {
    }
}

public class QueratorMapSelectionEvent : QueratorMatchTeamEvent
{
    [JsonPropertyName("map_name")]
    public required string MapName { get; init; }

    protected QueratorMapSelectionEvent(string eventName) : base(eventName)
    {
    }
}

public class QueratorMapPickedEvent : QueratorMapSelectionEvent
{
    [JsonPropertyName("map_number")]
    public required int MapNumber { get; init; }

    public QueratorMapPickedEvent() : base("map_picked")
    {
    }
}

public class QueratorMapVetoedEvent : QueratorMapSelectionEvent
{
    public QueratorMapVetoedEvent() : base("map_vetoed")
    {
    }
}

public class QueratorSidePickedEvent : QueratorMapSelectionEvent
{
    [JsonPropertyName("map_number")]
    public required int MapNumber { get; init; }

    [JsonPropertyName("side")]
    public required string Side { get; init; }

    public QueratorSidePickedEvent() : base("side_picked")
    {
    }
}

public class QueratorDemoUploadedEvent : QueratorMatchEvent
{
    [JsonPropertyName("map_number")]
    public required int MapNumber { get; init; }

    [JsonPropertyName("filename")]
    public required string FileName { get; init; }

    [JsonPropertyName("success")]
    public bool Success { get; set; }

    public QueratorDemoUploadedEvent() : base("demo_upload_ended")
    {
    }
}