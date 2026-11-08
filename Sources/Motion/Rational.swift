import Rational

extension Rational {
    static func exact(_ numerator: Int, _ denominator: Int) -> Self {
        do throws(Rational.Error) {
            return try Rational(numerator: numerator, denominator: denominator)
        } catch {
            preconditionFailure("checked by the caller")
        }
    }

    /// The whole seconds or frames below a non-negative media time.
    var floor: Int {
        precondition(!numerator.isNegative, "media time is never negative")
        do throws(Integer.Error) {
            return try numerator.quotientAndRemainder(dividingBy: denominator).quotient.exactly(Int.self) ?? Int.max
        } catch {
            preconditionFailure("a rational's denominator is never zero")
        }
    }

    func over(_ other: Self) -> Self {
        do throws(Rational.Error) {
            return try divided(by: other)
        } catch {
            preconditionFailure("a frame rate is never zero")
        }
    }
}
