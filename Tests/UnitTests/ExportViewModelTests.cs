using Microsoft.VisualStudio.TestTools.UnitTesting;
using Moq;
using System.IO;

namespace WheelHours.Tests.UnitTests
{
    [TestClass]
    public class ExportViewModelTests
    {
        private Mock<IEntitlementService> _entitlementServiceMock;
        private Mock<ISupervisorSignatureService> _signatureServiceMock;
        private ExportViewModel _exportViewModel;

        [TestInitialize]
        public void Initialize()
        {
            _entitlementServiceMock = new Mock<IEntitlementService>();
            _signatureServiceMock = new Mock<ISupervisorSignatureService>();
            _exportViewModel = new ExportViewModel(_entitlementServiceMock.Object, _signatureServiceMock.Object);
        }

        [TestMethod]
        public void TestPDFGeneration_WithValidData_GeneratesFile()
        {
            // Arrange
            var data = "Test Data";
            var expectedFilePath = Path.GetTempFileName();
            File.WriteAllText(expectedFilePath, data);

            _entitlementServiceMock.Setup(service => service.HasEntitlement(It.IsAny<string>())).Returns(true);
            _signatureServiceMock.Setup(service => service.SignDocument(It.IsAny<string>())).Returns(data);

            // Act
            _exportViewModel.ExportPDF("Test Data", expectedFilePath);

            // Assert
            File.Exists(expectedFilePath).ShouldBeTrue();
            File.ReadAllText(expectedFilePath).ShouldBe(data);

            File.Delete(expectedFilePath);
        }

        [TestMethod]
        public void TestExportPDF_WithInvalidEntitlement_DoesNotGenerateFile()
        {
            // Arrange
            _entitlementServiceMock.Setup(service => service.HasEntitlement(It.IsAny<string>())).Returns(false);
            var expectedFilePath = Path.GetTempFileName();

            // Act & Assert
            Should.Throw<UnauthorizedAccessException>(() => _exportViewModel.ExportPDF("Test Data", expectedFilePath));

            File.Exists(expectedFilePath).ShouldBeFalse();
        }

        [TestMethod]
        public void TestExportPDF_WithException_DoesNotGenerateFile()
        {
            // Arrange
            _entitlementServiceMock.Setup(service => service.HasEntitlement(It.IsAny<string>())).Returns(true);
            _signatureServiceMock.Setup(service => service.SignDocument(It.IsAny<string>())).Throws(new IOException("Error signing document"));

            var expectedFilePath = Path.GetTempFileName();

            // Act & Assert
            Should.Throw<IOException>(() => _exportViewModel.ExportPDF("Test Data", expectedFilePath));

            File.Exists(expectedFilePath).ShouldBeFalse();
        }
    }
}
