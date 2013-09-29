module Logging

using Match

import Base.show

export debug, info, warn, err, critical, log,
       @debug, @info, @warn, @err, @critical, @loglevel,
       Logger,
       LogLevel, DEBUG, INFO, WARNING, ERROR, CRITICAL

include("enum.jl")

@enum LogLevel DEBUG INFO WARNING ERROR CRITICAL

type Logger
    name::String
    level::LogLevel
    output::IO
    parent::Logger

    Logger(name::String, level::LogLevel, output::IO, parent::Logger) = new(name, level, output, parent)
    Logger(name::String, level::LogLevel, output::IO) = (x = new(); x.name = name; x.level=level; x.output=output; x.parent=x)
end

show(io::IO, logger::Logger) = print(io, "Logger(", join([logger.name, 
                                                          logger.level, 
                                                          logger.output,
                                                          logger.parent.name], ","), ")")

const _root = Logger("root", WARNING, STDERR)
Logger(name::String;args...) = configure(Logger(name, WARNING, STDERR); args...)

for (fn,lvl,clr) in ((:debug,    DEBUG,    :cyan),
                     (:info,     INFO,     :blue),
                     (:warn,     WARNING,  :magenta),
                     (:err,      ERROR,    :red),
                     (:critical, CRITICAL, :red))

    @eval function $fn(msg::String, logger = _root)
        if $lvl >= logger.level
            Base.print_with_color($(Expr(:quote, clr)), logger.output, string($lvl), ":", logger.name, ":", msg, "\n")
        end
    end
end

macro loglevel(level)
    args = Any[]
    push!(args, :(Logging._root.level = $(esc(level))))
    for (fn,lvl,clr) in ((:debug,    Logging.DEBUG,    :cyan),
                         (:info,     Logging.INFO,     :blue),
                         (:warn,     Logging.WARNING,  :magenta),
                         (:err,      Logging.ERROR,    :red),
                         (:critical, Logging.CRITICAL, :red))
        push!(args, 
            :(if $lvl >= $(esc(level))
                global macro $fn(msg::String)
                    Base.print_with_color($(Expr(:quote, clr)), Logging._root.output, string($lvl), ":", Logging._root.name, ":", msg, "\n")
                end
              else
                global macro $fn(msg::String) end
              end))
    end
    Expr(:block, args...)
end

@loglevel(WARNING)

function configure(logger=_root; args...)
    for (tag, val) in args
        if tag == :parent
            logger.parent = parent = val::Logger
            logger.level = parent.level
            logger.output = parent.output
        end
    end

    for (tag, val) in args
        @match tag begin
            :io       => logger.output = val::IO
            :filename => logger.output = open(val, "w")
            :level    => if logger == _root;  @loglevel(val::LogLevel) else logger.level  = val::LogLevel end
            :parent   => logger.parent = val::Logger
            unk       => Base.error("Logging: unknown configure argument \"$unk\"")
        end
    end

    logger
end

end # module
