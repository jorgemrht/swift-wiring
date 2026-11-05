import Testing
import Wiring

@MainActor
struct IsolationTests {
    @Test func anIsolatedContainerReplacesTheCurrentContainerOnlyDuringTheOperation() async {
        let root = Container.current

        let isolated = await Container.withIsolatedContainer { Container.current }

        #expect(isolated !== root)
        #expect(Container.current === root)
    }

    @Test func anIsolatedContainerStartsEmpty() async {
        await Container.withIsolatedContainer {
            #expect(Container.current.greeting() == "default")
        }
    }

    @Test(arguments: 0..<20)
    func eachParallelCaseHasItsOwnContainer(index: Int) async throws {
        try await Container.withIsolatedContainer {
            Container.current.greeting.register { "case \(index)" }
            try await Task.sleep(for: .milliseconds(10))
            #expect(Container.current.greeting() == "case \(index)")
        }
    }
}
